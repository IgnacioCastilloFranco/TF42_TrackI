/**
 * @author      ICASTILLOF
 * @since       10/07/2026
 * @desc        Clase de pruebas unitarias para VRT_SRV_InvoiceGenerator.
 *              Cubre: generación exitosa de factura, envío de correos,
 *              prevención de duplicados e inserción de logs de proceso (éxito/error).
 *
 * @history     10/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
private class VRT_SRV_InvoiceGenerator_Test {

    // ──────────────────────────────────────────────────────────────────────
    // Test Data Factory
    // ──────────────────────────────────────────────────────────────────────

    private static Integer vehicleCounter = 0;

    private static Account createAccount(String email) {
        return new Account(
            Name = 'Invoice Test Account',
            VRT_TXT_Email__c = email
        );
    }

    private static VRT_Vehicle__c createVehicle() {
        vehicleCounter++;
        return new VRT_Vehicle__c(
            VRT_TXT_Brand__c        = 'Seat',
            VRT_TXT_Model__c        = 'Ibiza',
            VRT_SEL_VehicleType__c  = 'Coche',
            VRT_FLG_Available__c    = true,
            VRT_SEL_Status__c       = 'Listo',
            VRT_NUM_Mileage__c      = 1000,
            VRT_NUM_Usage__c        = 0,
            VRT_TXT_LicensePlate__c = 'I' + String.valueOf(vehicleCounter).leftPad(6, '0'),
            VRT_NUM_Passengers__c   = 5,
            VRT_SEL_EnergyType__c   = 'Gasolina'
        );
    }

    private static VRT_Tarifa__c createTarifa(Decimal pricePerDay) {
        return new VRT_Tarifa__c(
            VRT_SEL_Season__c      = 'Baja',
            VRT_SEL_VehicleType__c = 'Coche',
            VRT_DIV_PricePerDay__c = pricePerDay,
            VRT_FLG_Active__c      = true
        );
    }

    private static VRT_Rental__c createRental(Id vehicleId, Id accountId, Date startDate, Date endDate) {
        return new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = 'En curso',
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );
    }

    // ──────────────────────────────────────────────────────────────────────
    // Tests
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void generateInvoice_exito_creaFacturaYLogExito() {
        // Arrange
        Account acc = createAccount('cliente@test.com');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle();
        insert vehicle;

        insert createTarifa(100);

        // Alquiler de 5 días → 500€
        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, 
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 6));
        insert rental;

        // Act
        Test.startTest();
        // Cambiar a Completado para disparar el trigger handler after update
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest(); // Fuerza la ejecución del Queueable asíncrono

        // Assert
        List<VRT_Factura__c> invoices = [
            SELECT Id, VRT_LKP_Rental__c, VRT_DIV_Amount__c 
            FROM VRT_Factura__c 
            WHERE VRT_LKP_Rental__c = :rental.Id
        ];
        System.assertEquals(1, invoices.size(), 
            'Debe haberse creado exactamente una factura.');
        System.assertEquals(500.00, invoices[0].VRT_DIV_Amount__c, 
            'El importe de la factura debe coincidir con el coste total del alquiler (500€).');

        List<VRT_LogProceso__c> logs = [
            SELECT Id, VRT_SEL_Status__c, VRT_TXT_Message__c 
            FROM VRT_LogProceso__c 
            WHERE VRT_LKP_Rental__c = :rental.Id
        ];
        System.assertEquals(1, logs.size(), 
            'Debe haberse registrado un log del proceso.');
        System.assertEquals('Éxito', logs[0].VRT_SEL_Status__c, 
            'El estado del log debe ser Éxito.');
        System.assert(logs[0].VRT_TXT_Message__c.contains('Factura generada con éxito'), 
            'El mensaje del log debe indicar éxito.');
        System.assert(logs[0].VRT_TXT_Message__c.contains('cliente@test.com'), 
            'El mensaje del log debe mencionar la dirección de correo notificada.');
    }

    @IsTest
    static void generateInvoice_sinEmail_creaFacturaConAvisoEnLog() {
        // Arrange
        Account acc = createAccount(null); // Sin email
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle();
        insert vehicle;

        insert createTarifa(100);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, 
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 6));
        insert rental;

        // Act
        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        // Assert
        List<VRT_Factura__c> invoices = [SELECT Id FROM VRT_Factura__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, invoices.size(), 'La factura debe crearse aun sin email.');

        List<VRT_LogProceso__c> logs = [SELECT Id, VRT_SEL_Status__c, VRT_TXT_Message__c FROM VRT_LogProceso__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, logs.size());
        System.assertEquals('Éxito', logs[0].VRT_SEL_Status__c);
        System.assert(logs[0].VRT_TXT_Message__c.contains('No se envió correo'), 
            'El mensaje debe registrar el aviso de que no se envió correo.');
    }

    @IsTest
    static void generateInvoice_duplicado_evitaNuevaFacturaYLogeaAviso() {
        // Arrange
        Account acc = createAccount('cliente@test.com');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle();
        insert vehicle;

        insert createTarifa(100);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, 
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 6));
        insert rental;

        // Insertar factura previa para simular que ya está facturado
        VRT_Factura__c preExisting = new VRT_Factura__c(
            VRT_LKP_Rental__c = rental.Id,
            VRT_DIV_Amount__c = 500.00,
            VRT_DAT_InvoiceDate__c = Date.today()
        );
        insert preExisting;

        // Act
        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        // Assert
        List<VRT_Factura__c> invoices = [SELECT Id FROM VRT_Factura__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, invoices.size(), 
            'No debe haberse creado ninguna factura nueva (evita duplicación).');

        List<VRT_LogProceso__c> logs = [SELECT Id, VRT_SEL_Status__c, VRT_TXT_Message__c FROM VRT_LogProceso__c WHERE VRT_LKP_Rental__c = :rental.Id];
        System.assertEquals(1, logs.size(), 'Debe existir el log explicativo.');
        System.assertEquals('Éxito', logs[0].VRT_SEL_Status__c);
        System.assert(logs[0].VRT_TXT_Message__c.contains('ya ha sido facturado anteriormente'), 
            'El log debe registrar que se omitió por estar facturado.');
    }

    @IsTest
    static void generateInvoice_error_registraErrorEnLog() {
        // Arrange
        Account acc = createAccount('cliente@test.com');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle();
        insert vehicle;

        insert createTarifa(100);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, 
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 6));
        insert rental;

        // Forzar un coste de 999.99 para gatillar la regla de validación VRT_VR_AmountCannotBeNegative en Factura__c
        rental.VRT_DIV_TotalCost__c = 999.99;
        update rental;

        // Act
        Test.startTest();
        rental.VRT_SEL_Status__c = 'Completado';
        update rental;
        Test.stopTest();

        // Assert
        List<VRT_LogProceso__c> logs = [
            SELECT Id, VRT_SEL_Status__c, VRT_TXT_Message__c 
            FROM VRT_LogProceso__c 
            WHERE VRT_LKP_Rental__c = :rental.Id
        ];
        System.assertEquals(1, logs.size(), 'Debe haberse registrado un log de error.');
        System.assertEquals('Error', logs[0].VRT_SEL_Status__c, 'El estado del log debe ser Error.');
        System.assert(logs[0].VRT_TXT_Message__c.contains('Fallo al insertar factura'), 
            'El mensaje del log debe registrar el fallo DML.');
    }
}
