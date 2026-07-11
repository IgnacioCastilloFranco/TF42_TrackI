/**
 * @author      ICASTILLOF
 * @since       10/07/2026
 * @desc        Clase asíncrona Queueable para la generación automática
 *              de facturas, envío de notificaciones y registro de logs.
 *              Desacoplamiento Asíncrono: Uso de Queueable Apex para 
 *              desacoplar el procesamiento principal (Trigger Handler en onAfterUpdate) 
 *              de la inserción de facturas y del envío de correos, 
 *              mejorando el rendimiento y evitando bloqueos.
 *
 * @history     10/07/2026 - ICASTILLOF - Creación de la clase
 */
public class VRT_SRV_InvoiceGenerator implements Queueable {

    private List<Id> rentalIds;

    public VRT_SRV_InvoiceGenerator(List<Id> rentalIds) {
        this.rentalIds = rentalIds;
    }

    public void execute(QueueableContext context) {
        if (rentalIds == null || rentalIds.isEmpty()) {
            return;
        }

        List<VRT_Factura__c> invoicesToInsert = new List<VRT_Factura__c>();
        List<VRT_LogProceso__c> logsToInsert = new List<VRT_LogProceso__c>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // 1. Obtener información de los alquileres
        Map<Id, VRT_Rental__c> rentalsMap = new Map<Id, VRT_Rental__c>([
            SELECT Id, Name, VRT_DIV_TotalCost__c, 
                   VRT_LKP_Account__c, VRT_LKP_Account__r.Name, 
                   VRT_LKP_Account__r.VRT_TXT_Email__c
            FROM VRT_Rental__c
            WHERE Id IN :rentalIds
        ]);

        // 2. Prevención de duplicados: consultar facturas existentes
        Set<Id> alreadyInvoicedIds = new Set<Id>();
        for (VRT_Factura__c fact : [
            SELECT VRT_LKP_Rental__c 
            FROM VRT_Factura__c 
            WHERE VRT_LKP_Rental__c IN :rentalIds
        ]) {
            alreadyInvoicedIds.add(fact.VRT_LKP_Rental__c);
        }

        // 3. Filtrar alquileres elegibles y preparar facturas
        List<VRT_Rental__c> eligibleRentals = new List<VRT_Rental__c>();
        for (VRT_Rental__c rental : rentalsMap.values()) {
            if (alreadyInvoicedIds.contains(rental.Id)) {
                // Registrar log de aviso indicando que ya está facturado
                VRT_LogProceso__c dupeLog = new VRT_LogProceso__c(
                    VRT_TXT_ProcessName__c = 'Facturación Automática',
                    VRT_SEL_Status__c       = 'Éxito',
                    VRT_LKP_Rental__c       = rental.Id,
                    VRT_TXT_Message__c      = 'El alquiler ya ha sido facturado anteriormente. Se omite duplicado.'
                );
                logsToInsert.add(dupeLog);
                continue;
            }

            eligibleRentals.add(rental);

            VRT_Factura__c invoice = new VRT_Factura__c(
                VRT_LKP_Rental__c       = rental.Id,
                VRT_DIV_Amount__c       = rental.VRT_DIV_TotalCost__c != null ? rental.VRT_DIV_TotalCost__c : 0,
                VRT_DAT_InvoiceDate__c  = Date.today()
            );
            invoicesToInsert.add(invoice);
        }

        if (invoicesToInsert.isEmpty() && logsToInsert.isEmpty()) {
            return; // Nada que hacer
        }

        // 4. Intentar insertar facturas
        Map<Id, VRT_Factura__c> rentalToInvoiceMap = new Map<Id, VRT_Factura__c>();
        if (!invoicesToInsert.isEmpty()) {
            Database.SaveResult[] srList = Database.insert(invoicesToInsert, false); //  inserción en base de datos con permitido de éxito parcial (debido al parámetro false, llamado allOrNone).  Devuelve un array donde cada elemento SaveResult se corresponde en posición (mismo índice i) con la lista invoicesToInsert.
            
            for (Integer i = 0; i < srList.size(); i++) {
                Database.SaveResult sr = srList[i];
                VRT_Rental__c rental = eligibleRentals[i];
                
                if (sr.isSuccess()) {
                    rentalToInvoiceMap.put(rental.Id, invoicesToInsert[i]);
                    
                    // Preparar log de éxito
                    String msg = 'Factura generada con éxito (' + sr.getId() + ').';
                    String emailAddr = rental.VRT_LKP_Account__r.VRT_TXT_Email__c;
                    
                    if (String.isNotBlank(emailAddr)) {
                        // Preparar correo
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        mail.setToAddresses(new List<String>{ emailAddr });
                        mail.setSubject('Tu factura para el alquiler ' + rental.Name);
                        mail.setPlainTextBody(
                            'Hola ' + rental.VRT_LKP_Account__r.Name + ',\n\n' +
                            'Tu factura para el alquiler ' + rental.Name + ' ha sido generada por un importe de ' + 
                            rental.VRT_DIV_TotalCost__c + ' €.\n\n' +
                            'Gracias por confiar en nosotros.'
                        );
                        emailsToSend.add(mail);
                        msg += ' Correo de notificación encolado para: ' + emailAddr;
                    } else {
                        msg += ' No se envió correo de notificación porque la Cuenta asociada no tiene Email configurado.';
                    }

                    logsToInsert.add(new VRT_LogProceso__c(
                        VRT_TXT_ProcessName__c = 'Facturación Automática',
                        VRT_SEL_Status__c       = 'Éxito',
                        VRT_LKP_Rental__c       = rental.Id,
                        VRT_TXT_Message__c      = msg
                    ));
                } else {
                    // Preparar log de error
                    List<String> errorMsgs = new List<String>();
                    for (Database.Error err : sr.getErrors()) {
                        errorMsgs.add(err.getMessage());
                    }
                    logsToInsert.add(new VRT_LogProceso__c(
                        VRT_TXT_ProcessName__c = 'Facturación Automática',
                        VRT_SEL_Status__c       = 'Error',
                        VRT_LKP_Rental__c       = rental.Id,
                        VRT_TXT_Message__c      = 'Fallo al insertar factura: ' + String.join(errorMsgs, '; ')
                    ));
                }
            }
        }

        // 5. Enviar correos encolados
        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.sendEmail(emailsToSend);
            } catch (Exception e) {
                // Si falla el envío de correo, modificamos logs correspondientes
                for (VRT_LogProceso__c log : logsToInsert) {
                    if (log.VRT_SEL_Status__c == 'Éxito' && log.VRT_TXT_Message__c.contains('encolado')) {
                        log.VRT_SEL_Status__c = 'Error';
                        log.VRT_TXT_Message__c += ' [FALLO EN ENVÍO DE EMAIL: ' + e.getMessage() + ']';
                    }
                }
            }
        }

        // 6. Insertar todos los logs
        if (!logsToInsert.isEmpty()) {
            Database.insert(logsToInsert, false);
        }
    }
}
