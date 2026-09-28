/**
 * @description Valida la unicidad de la combinación temporada y tipo de
 *              vehículo para las tarifas.
 */
public without sharing class VRT_SRV_TarifaUniqueness {

    private static final String DUPLICATE_MESSAGE =
        'Ya existe una tarifa con la misma combinación de Temporada y Tipo de vehículo.';

    public static void validate(List<VRT_Tarifa__c> tarifas) {
        Map<String, List<VRT_Tarifa__c>> incomingByKey = new Map<String, List<VRT_Tarifa__c>>();
        Set<String> keysToCheck = new Set<String>();
        Set<Id> existingIds = new Set<Id>();

        for (VRT_Tarifa__c tarifa : tarifas) {
            if (tarifa.Id != null) {
                existingIds.add(tarifa.Id);
            }

            String key = buildKey(tarifa);
            if (key == null) {
                continue;
            }

            keysToCheck.add(key);
            if (!incomingByKey.containsKey(key)) {
                incomingByKey.put(key, new List<VRT_Tarifa__c>());
            }
            incomingByKey.get(key).add(tarifa);
        }

        for (String key : incomingByKey.keySet()) {
            List<VRT_Tarifa__c> matchingIncoming = incomingByKey.get(key);
            if (matchingIncoming.size() > 1) {
                for (VRT_Tarifa__c tarifa : matchingIncoming) {
                    tarifa.addError(DUPLICATE_MESSAGE);
                }
            }
        }

        if (keysToCheck.isEmpty()) {
            return;
        }

        for (VRT_Tarifa__c existing : [
            SELECT Id, VRT_SEL_Season__c, VRT_SEL_VehicleType__c
            FROM VRT_Tarifa__c
            WHERE Id NOT IN :existingIds
        ]) {
            String key = buildKey(existing);
            if (key == null || !keysToCheck.contains(key)) {
                continue;
            }

            for (VRT_Tarifa__c incoming : incomingByKey.get(key)) {
                incoming.addError(DUPLICATE_MESSAGE);
            }
        }
    }

    private static String buildKey(VRT_Tarifa__c tarifa) {
        if (String.isBlank(tarifa.VRT_SEL_Season__c)
            || String.isBlank(tarifa.VRT_SEL_VehicleType__c)) {
            return null;
        }

        return tarifa.VRT_SEL_Season__c.trim().toLowerCase()
            + '|'
            + tarifa.VRT_SEL_VehicleType__c.trim().toLowerCase();
    }
}
