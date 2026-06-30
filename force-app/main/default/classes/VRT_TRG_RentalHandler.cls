/**
 * @author		AMADRIDN (NTT Data)
 * @since		04/04/2024
 * @desc		Handler class for trigger VRT_TRG_Rental
 * @history		04/04/2024 - AMADRIDN - Created class
 * 				08/04/2024 - AMADRIDN - Added comments
 * 				12/04/2024 - AMADRIDN - Added onAfterUpdate
 */
public class VRT_TRG_RentalHandler {
    /**
     * @desc	After Insert Handler
     * @param	triggerNew: list of rentals inserted
     */
    public void onAfterInsert(List<VRT_Rental__c> triggerNew) {
        VRT_TRG_RentalHandlerHelper.updateConditionVehicle(triggerNew);
    }
    
    /**
     * @desc	After Update Handler
     * @param	oldMap: map with rentals in old state 
     * @param	newMap: map with rentals in new state 
     */
    public void onAfterUpdate(Map<Id, VRT_Rental__c> oldMap, Map<Id, VRT_Rental__c> newMap) {
        VRT_TRG_RentalHandlerHelper.updateVehicleRentalCompleted(oldMap, newMap);
    }
}