@IsTest
private class VRT_SRV_TarifaUniqueness_Test {

    @IsTest
    static void duplicateCombinationOnInsertIsRejected() {
        insert tariff('Alta', 'coche', 35);

        VRT_Tarifa__c duplicateTariff = tariff('alta', 'Coche', 88);

        Database.SaveResult result = Database.insert(duplicateTariff, false);

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains('misma combinación'),
            'Debe explicar que la combinación ya existe.'
        );
    }

    @IsTest
    static void duplicateCombinationInSameBulkInsertIsRejected() {
        List<VRT_Tarifa__c> tariffs = new List<VRT_Tarifa__c>{
            tariff('Media', 'moto', 24),
            tariff('media', 'MOTO', 30)
        };

        Database.SaveResult[] results = Database.insert(tariffs, false);

        System.assertEquals(false, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
    }

    @IsTest
    static void differentCombinationIsAllowed() {
        insert tariff('Baja', 'coche', 25);

        Database.SaveResult result = Database.insert(tariff('Baja', 'moto', 20), false);

        System.assertEquals(true, result.isSuccess());
    }

    @IsTest
    static void updatingUnchangedTariffIsAllowed() {
        VRT_Tarifa__c existing = tariff('Alta', 'coche', 35);
        insert existing;

        existing.VRT_DIV_PricePerDay__c = 40;
        Database.SaveResult result = Database.update(existing, false);

        System.assertEquals(true, result.isSuccess());
    }

    private static VRT_Tarifa__c tariff(String season, String vehicleType, Decimal price) {
        return new VRT_Tarifa__c(
            Name = season + ' - ' + vehicleType + ' test',
            VRT_SEL_Season__c = season,
            VRT_SEL_VehicleType__c = vehicleType,
            VRT_DIV_PricePerDay__c = price,
            VRT_FLG_Active__c = true
        );
    }
}
