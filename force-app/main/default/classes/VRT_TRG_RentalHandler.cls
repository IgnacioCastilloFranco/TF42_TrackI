/**
 * @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Handler class for trigger VRT_TRG_Rental
 * @history		04/04/2024 - AMADRIDN - Created class
 * 				08/04/2024 - AMADRIDN - Added comments
 * 				12/04/2024 - AMADRIDN - Added onAfterUpdate
 * 				07/07/2026 - ICASTILLOF - Added onBeforeInsert/onBeforeUpdate for pricing & availability
 * 				09/07/2026 - ICASTILLOF - Added approval submission in onAfterInsert/onAfterUpdate
 */
public class VRT_TRG_RentalHandler {

    // ──────────────────────────────────────────────────────────────────────
    // Before Insert
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc	Before Insert Handler – calculates pricing and validates availability
     * @param	triggerNew: list of rentals being inserted
     */
    public void onBeforeInsert(List<VRT_Rental__c> triggerNew) {
        // Calcular precio total del alquiler
        VRT_SRV_PricingEngine.calculateTotalCost(triggerNew);

        // Validar disponibilidad del vehículo en las fechas solicitadas
        VRT_SRV_AvailabilityChecker.validateAvailability(triggerNew);
    }

    // ──────────────────────────────────────────────────────────────────────
    // Before Update
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc	Before Update Handler – recalculates pricing and revalidates
     *          availability when dates, vehicle or account change
     * @param	oldMap: map with rentals in old state
     * @param	newMap: map with rentals in new state
     */
    public void onBeforeUpdate(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap) {
        List<VRT_Rental__c> rentalsToReprice = new List<VRT_Rental__c>();

        for (Id rentalId : newMap.keySet()) {
            VRT_Rental__c oldRental = oldMap.get(rentalId);
            VRT_Rental__c newRental = newMap.get(rentalId);

            // Recalcular precio si cambian fechas, vehículo o cuenta
            if (oldRental.VRT_DAT_InitialDate__c != newRental.VRT_DAT_InitialDate__c
                || oldRental.VRT_DAT_FinalDate__c != newRental.VRT_DAT_FinalDate__c
                || oldRental.VRT_LKP_Vehicle__c  != newRental.VRT_LKP_Vehicle__c
                || oldRental.VRT_LKP_Account__c  != newRental.VRT_LKP_Account__c) {
                rentalsToReprice.add(newRental);
            }
        }

        if (!rentalsToReprice.isEmpty()) {
            VRT_SRV_PricingEngine.calculateTotalCost(rentalsToReprice);

            // Validar disponibilidad del vehículo en las nuevas fechas
            VRT_SRV_AvailabilityChecker.validateAvailability(rentalsToReprice);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // After Insert
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc	After Insert Handler
     * @param	triggerNew: list of rentals inserted
     */
    public void onAfterInsert(List<VRT_Rental__c> triggerNew) {
        VRT_TRG_RentalHandlerHelper.updateConditionVehicle(triggerNew);

        // Enviar a aprobación financiera si el coste supera el umbral
        VRT_SRV_ApprovalManager.submitForApprovalOnInsert(triggerNew);
    }

    // ──────────────────────────────────────────────────────────────────────
    // After Update
    // ──────────────────────────────────────────────────────────────────────
    
    /**
     * @desc	After Update Handler
     * @param	oldMap: map with rentals in old state 
     * @param	newMap: map with rentals in new state 
     */
    public void onAfterUpdate(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap) {
        VRT_TRG_RentalHandlerHelper.updateVehicleRentalCompleted(oldMap, newMap);

        // Enviar a aprobación financiera si el coste ha cambiado y supera el umbral
        VRT_SRV_ApprovalManager.submitForApprovalOnUpdate(oldMap, newMap);

        // Capturar alquileres completados para facturación automática asíncrona
        List<Id> completedRentalIds = new List<Id>();
        for (Id rentalId : newMap.keySet()) {
            VRT_Rental__c oldRental = oldMap.get(rentalId);
            VRT_Rental__c newRental = newMap.get(rentalId);

            if (oldRental.VRT_SEL_Status__c != 'Completado' && newRental.VRT_SEL_Status__c == 'Completado') {
                completedRentalIds.add(newRental.Id);
            }
        }

        if (!completedRentalIds.isEmpty()) {
            System.enqueueJob(new VRT_SRV_InvoiceGenerator(completedRentalIds));
        }
    }
}