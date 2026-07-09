/*
 * @author      ICASTILLOF
 * @since       07/07/2026
 * @desc        Service para validar disponibilidad de vehículos evitando solapamientos
 *              entre rentals. Método bulk-safe para usarse en before insert / before update
 *              del trigger de VRT_Rental__c.
 *
 * Reglas principales:
 * - Regla de solapamiento: startA < endB AND endA > startB (compare estricto)
 * - Se permite que un alquiler termine el mismo día que otro empieza (no se considera solapamiento)
 * - Se realiza una consulta bulk por vehículo y un filtrado por rango de fechas para eficiencia
 */
public with sharing class VRT_SRV_AvailabilityChecker {

    /**
     * Valida disponibilidad de la lista de rentals pasada como parámetro.
     * Si existen conflictos se llama a addError en los registros afectados para
     * detener el DML en contexto before.
     * @param rentals Lista bulk de VRT_Rental__c (before insert / before update)
     */
    public static void validateAvailability(List<VRT_Rental__c> rentals) {
        if (rentals == null || rentals.isEmpty()) {
            return;
        }

        // Agrupar rentals entrantes por vehículo y recopilar ids/fechas
        Map<Id, List<VRT_Rental__c>> rentalsByVehicle = new Map<Id, List<VRT_Rental__c>>();
        Set<Id> vehicleIds = new Set<Id>();
        Set<Id> incomingIds = new Set<Id>();//rentalIDs

        Date globalMinStart;
        Date globalMaxEnd;

        for (VRT_Rental__c r : rentals) {//Iterar sobre cada rental entrante para agruparlos por vehículo (en rentalsByVehicle)
            // Comprobar que tenga vehículo y fechas
            if (r.VRT_LKP_Vehicle__c == null) {
                // No hay vehículo asociado: dejar que otras validaciones lo gestionen
                continue;
            }

            Date startDate = r.VRT_DAT_InitialDate__c;
            Date endDate = r.VRT_DAT_FinalDate__c;

            if (startDate == null || endDate == null) {
                r.addError('Fechas de inicio/fin incompletas: no se puede validar disponibilidad.');//En Apex, addError() se usa dentro de triggers o validaciones para impedir que el registro se guarde cuando no cumple una condición.
                continue;
            }

            vehicleIds.add(r.VRT_LKP_Vehicle__c);

            if (r.Id != null) {
                incomingIds.add(r.Id);
            }

            // calcular min/max global para reducir el rango de la query
            if (globalMinStart == null || startDate < globalMinStart) {
                globalMinStart = startDate;
            }
            if (globalMaxEnd == null || endDate > globalMaxEnd) {
                globalMaxEnd = endDate;
            }

            if (!rentalsByVehicle.containsKey(r.VRT_LKP_Vehicle__c)) {
                rentalsByVehicle.put(r.VRT_LKP_Vehicle__c, new List<VRT_Rental__c>());
            }
            rentalsByVehicle.get(r.VRT_LKP_Vehicle__c).add(r);
        }

        if (vehicleIds.isEmpty()) {
            return;
        }

        // Queryar alquileres existentes que potencialmente solapen con el rango global
        // Excluir los ids entrantes (en caso de update) para no compararse consigo mismos
        List<VRT_Rental__c> existing = [
            SELECT Id, Name, VRT_LKP_Vehicle__c, VRT_DAT_InitialDate__c, VRT_DAT_FinalDate__c, VRT_SEL_Status__c
            FROM VRT_Rental__c
            WHERE VRT_LKP_Vehicle__c IN :vehicleIds
            AND Id NOT IN :incomingIds
            AND VRT_DAT_InitialDate__c <= :globalMaxEnd
            AND VRT_DAT_FinalDate__c >= :globalMinStart
        ];

        // Indexar por vehículo para búsquedas rápidas
        Map<Id, List<VRT_Rental__c>> existingByVehicle = new Map<Id, List<VRT_Rental__c>>();
        for (VRT_Rental__c ex : existing) {
            if (!existingByVehicle.containsKey(ex.VRT_LKP_Vehicle__c)) {
                existingByVehicle.put(ex.VRT_LKP_Vehicle__c, new List<VRT_Rental__c>());
            }
            existingByVehicle.get(ex.VRT_LKP_Vehicle__c).add(ex);
        }

        // 1) Comprobar conflictos contra registros existentes en BD
        for (Id vehicleId : rentalsByVehicle.keySet()) {
            List<VRT_Rental__c> batchList = rentalsByVehicle.get(vehicleId);
            List<VRT_Rental__c> existingList = existingByVehicle.containsKey(vehicleId)
                ? existingByVehicle.get(vehicleId)
                : new List<VRT_Rental__c>();

            if (existingList.isEmpty()) {
                continue;
            }

            for (VRT_Rental__c newR : batchList) {
                Date newStart = newR.VRT_DAT_InitialDate__c;
                Date newEnd = newR.VRT_DAT_FinalDate__c;

                for (VRT_Rental__c ex : existingList) {
                    Date exStart = ex.VRT_DAT_InitialDate__c;
                    Date exEnd = ex.VRT_DAT_FinalDate__c;

                    // Regla de solapamiento: startA < endB AND endA > startB (estricto)
                    if (newStart < exEnd && newEnd > exStart) {
                        String msg = 'Conflicto de disponibilidad con el alquiler existente "' + ex.Name + '" (' +
                            (exStart != null ? exStart.format() : 'sin fecha inicio') + ' - ' +
                            (exEnd != null ? exEnd.format() : 'sin fecha fin') + ').';
                        newR.addError(msg);
                        break; // Ya marcado como error, pasar al siguiente newR
                    }
                }
            }
        }

        // 2) Comprobar conflictos intra-batch (dos nuevos que se solapan entre sí)
        for (Id vehicleId : rentalsByVehicle.keySet()) {
            List<VRT_Rental__c> batchList = rentalsByVehicle.get(vehicleId);
            Integer n = batchList.size();
            if (n < 2) continue;

            // Implementación simple O(n^2) (sin ordenar). El número de rentals por vehículo en una sola
            // transacción suele ser pequeño, por lo que este enfoque es aceptable y evita complejidad extra.

            // Implementación simple O(n^2) pero solo por vehículo y típicamente pequeño
            for (Integer i = 0; i < n; i++) {
                VRT_Rental__c a = batchList[i];
                Date aStart = a.VRT_DAT_InitialDate__c;
                Date aEnd = a.VRT_DAT_FinalDate__c;
                for (Integer j = i+1; j < n; j++) {
                    VRT_Rental__c b = batchList[j];
                    Date bStart = b.VRT_DAT_InitialDate__c;
                    Date bEnd = b.VRT_DAT_FinalDate__c;

                    if (aStart < bEnd && aEnd > bStart) {
                        String msg = 'Conflicto intra-batch: este alquiler se solapa con otro alquiler en la misma transacción.';
                        a.addError(msg);
                        b.addError(msg);
                    }
                }
            }
        }
    }
}
