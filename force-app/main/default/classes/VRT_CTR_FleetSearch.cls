/**
 * @author      ICASTILLOF
 * @since       11/07/2026
 * @desc        Controlador Apex para buscar vehículos en la flota
 *              según matrícula, marca o modelo (búsqueda parcial).
 *
 * @history     11/07/2026 - ICASTILLOF - Creación de la clase
 */
public with sharing class VRT_CTR_FleetSearch {

    /**
     * @desc    Busca vehículos por término parcial de marca, modelo o matrícula
     * @param   searchTerm: Término de búsqueda introducido por el usuario
     * @return  Lista de vehículos que coinciden con los criterios
     */
    @AuraEnabled(cacheable=true)
    public static List<VRT_Vehicle__c> searchVehicles(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<VRT_Vehicle__c>();
        }

        String safeSearchTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        return [
            SELECT Id, Name, 
                   VRT_TXT_Brand__c, 
                   VRT_TXT_Model__c, 
                   VRT_TXT_LicensePlate__c, 
                   VRT_SEL_VehicleType__c, 
                   VRT_SEL_Status__c, 
                   VRT_FLG_Available__c,
                   VRT_SEL_Condition__c
            FROM VRT_Vehicle__c
            WHERE VRT_TXT_LicensePlate__c LIKE :safeSearchTerm
               OR VRT_TXT_Brand__c LIKE :safeSearchTerm
               OR VRT_TXT_Model__c LIKE :safeSearchTerm
            WITH USER_MODE
            LIMIT 50
        ];
    }
}
