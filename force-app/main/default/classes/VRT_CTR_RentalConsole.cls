/**
 * @author      ICASTILLOF
 * @since       09/07/2026
 * @desc        Controller Apex para el LWC vrtRentalConsole.
 *              Expone métodos @AuraEnabled para obtener los alquileres
 *              de una cuenta y un resumen (KPIs) de los mismos.
 *
 * @history     09/07/2026 - ICASTILLOF - Creación de la clase
 */
public with sharing class VRT_CTR_RentalConsole {

    // ──────────────────────────────────────────────────────────────────────
    // Wrapper para KPIs
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Wrapper que encapsula los KPIs de resumen de alquileres
     *          de una cuenta. Se devuelve como objeto serializable al LWC.
     *          @AuraEnabled es la anotación que hace que una propiedad 
     *          Apex sea visible y accesible desde un LWC (o Aura component).
     *          Sin @AuraEnabled, cuando Salesforce serializa el objeto 
     *          RentalSummary a JSON para enviarlo al LWC, omitiría esa 
     *          propiedad. Con ella, la propiedad se incluye en la respuesta.
     *          El { get; set; } es la sintaxis de Apex para propiedades 
     *          automáticas (genera getter y setter implícitos). 
     *          Es necesario porque @AuraEnabled solo funciona sobre 
     *          propiedades, no sobre variables de instancia simples.
     */
    public class RentalSummary {
        @AuraEnabled public Integer totalRentals    { get; set; }
        @AuraEnabled public Integer activeRentals   { get; set; }
        @AuraEnabled public Integer completedRentals { get; set; }
        @AuraEnabled public Integer cancelledRentals { get; set; }
        @AuraEnabled public Decimal totalCost       { get; set; }

        public RentalSummary() {
            this.totalRentals     = 0;
            this.activeRentals    = 0;
            this.completedRentals = 0;
            this.cancelledRentals = 0;
            this.totalCost        = 0;
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Obtener alquileres por cuenta
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Devuelve la lista de alquileres asociados a una cuenta,
     *          incluyendo datos del vehículo relacionado.
     *          Ordenados por fecha de inicio descendente (más recientes primero).
     * @param   accountId Id de la cuenta
     * @return  List<VRT_Rental__c> con campos para la tabla del LWC
     */
    @AuraEnabled(cacheable=true)
    public static List<VRT_Rental__c> getRentalsByAccount(Id accountId) {
        if (accountId == null) {
            return new List<VRT_Rental__c>();
        }

        return [
            SELECT Id,
                   Name,
                   VRT_DAT_InitialDate__c,
                   VRT_DAT_FinalDate__c,
                   VRT_FOR_Duration__c,
                   VRT_SEL_Status__c,
                   VRT_SEL_PaymentStatus__c,
                   VRT_DIV_TotalCost__c,
                   VRT_LKP_Vehicle__c,
                   VRT_LKP_Vehicle__r.VRT_TXT_Brand__c,
                   VRT_LKP_Vehicle__r.VRT_TXT_Model__c,
                   VRT_LKP_Vehicle__r.VRT_TXT_LicensePlate__c
            FROM VRT_Rental__c
            WHERE VRT_LKP_Account__c = :accountId
            ORDER BY VRT_DAT_InitialDate__c DESC
            LIMIT 200
        ];
    }

    // ──────────────────────────────────────────────────────────────────────
    // Obtener resumen (KPIs)
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Devuelve un objeto RentalSummary con los KPIs agregados
     *          de los alquileres de una cuenta: totales, activos,
     *          completados, cancelados y coste total acumulado.
     * @param   accountId Id de la cuenta
     * @return  RentalSummary con los conteos y coste total
     */
    @AuraEnabled(cacheable=true)
    public static RentalSummary getRentalSummary(Id accountId) {
        RentalSummary summary = new RentalSummary();

        if (accountId == null) {
            return summary;
        }

        List<AggregateResult> results = [
            SELECT VRT_SEL_Status__c status,
                   COUNT(Id) rentalCount,
                   SUM(VRT_DIV_TotalCost__c) costSum
            FROM VRT_Rental__c
            WHERE VRT_LKP_Account__c = :accountId
            GROUP BY VRT_SEL_Status__c
        ];

        for (AggregateResult ar : results) {
            String status    = (String) ar.get('status');
            Integer count    = (Integer) ar.get('rentalCount');
            Decimal costSum  = ar.get('costSum') != null ? (Decimal) ar.get('costSum') : 0;

            summary.totalRentals += count;
            summary.totalCost    += costSum;

            if (status == 'En curso') {
                summary.activeRentals = count;
            } else if (status == 'Completado') {
                summary.completedRentals = count;
            } else if (status == 'Cancelado') {
                summary.cancelledRentals = count;
            }
        }

        return summary;
    }
}
