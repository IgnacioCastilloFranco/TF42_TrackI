/**
 * @description Garantiza que no existan dos tarifas con la misma
 *              combinación de temporada y tipo de vehículo.
 */
trigger VRT_TRG_Tarifa on VRT_Tarifa__c (before insert, before update) {
    VRT_SRV_TarifaUniqueness.validate(trigger.new);
}
