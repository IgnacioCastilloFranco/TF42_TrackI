/**
 * @author      ICASTILLOF
 * @since       11/07/2026
 * @desc        Clase de pruebas unitarias para VRT_CTR_FleetSearch.
 *              Valida la búsqueda por matrícula, marca, modelo y control de entrada.
 *
 * @history     11/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
private class VRT_CTR_FleetSearch_Test {

    @TestSetup
    static void setupData() {
        // Crear vehículos de prueba
        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>{
            new VRT_Vehicle__c(
                VRT_TXT_Brand__c        = 'Seat',
                VRT_TXT_Model__c        = 'Ibiza',
                VRT_SEL_VehicleType__c  = 'Coche',
                VRT_FLG_Available__c    = true,
                VRT_SEL_Status__c       = 'Listo',
                VRT_NUM_Mileage__c      = 1000,
                VRT_NUM_Usage__c        = 0,
                VRT_TXT_LicensePlate__c = '1234ABC',
                VRT_NUM_Passengers__c   = 5,
                VRT_SEL_EnergyType__c   = 'Gasolina'
            ),
            new VRT_Vehicle__c(
                VRT_TXT_Brand__c        = 'Yamaha',
                VRT_TXT_Model__c        = 'TMax',
                VRT_SEL_VehicleType__c  = 'Moto',
                VRT_FLG_Available__c    = false,
                VRT_SEL_Status__c       = 'En mantenimiento',
                VRT_NUM_Mileage__c      = 5000,
                VRT_NUM_Usage__c        = 10,
                VRT_TXT_LicensePlate__c = '5678DEF',
                VRT_NUM_Passengers__c   = 2,
                VRT_SEL_EnergyType__c   = 'Gasolina'
            ),
            new VRT_Vehicle__c(
                VRT_TXT_Brand__c        = 'Seat',
                VRT_TXT_Model__c        = 'León',
                VRT_SEL_VehicleType__c  = 'Coche',
                VRT_FLG_Available__c    = true,
                VRT_SEL_Status__c       = 'Listo',
                VRT_NUM_Mileage__c      = 2000,
                VRT_NUM_Usage__c        = 5,
                VRT_TXT_LicensePlate__c = '9012GHI',
                VRT_NUM_Passengers__c   = 5,
                VRT_SEL_EnergyType__c   = 'Gasolina'
            )
        };
        insert vehicles;
    }

    @IsTest
    static void searchVehicles_byBrand_returnsMatches() {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_CTR_FleetSearch.searchVehicles('Seat');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Debe encontrar 2 vehículos Seat.');
        Set<String> models = new Set<String>();
        for (VRT_Vehicle__c v : results) {
            models.add(v.VRT_TXT_Model__c);
        }
        System.assert(models.contains('Ibiza'), 'Debe contener el Ibiza.');
        System.assert(models.contains('León'), 'Debe contener el León.');
    }

    @IsTest
    static void searchVehicles_byModel_returnsMatches() {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_CTR_FleetSearch.searchVehicles('TMax');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Debe encontrar 1 vehículo Yamaha TMax.');
        System.assertEquals('Yamaha', results[0].VRT_TXT_Brand__c, 'La marca debe ser Yamaha.');
    }

    @IsTest
    static void searchVehicles_byLicensePlate_returnsMatches() {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_CTR_FleetSearch.searchVehicles('9012');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Debe encontrar 1 vehículo por matrícula parcial.');
        System.assertEquals('9012GHI', results[0].VRT_TXT_LicensePlate__c);
    }

    @IsTest
    static void searchVehicles_tooShort_returnsEmpty() {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_CTR_FleetSearch.searchVehicles('S');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Búsqueda de menos de 2 caracteres debe retornar vacío.');
    }

    @IsTest
    static void searchVehicles_blankOrNull_returnsEmpty() {
        Test.startTest();
        List<VRT_Vehicle__c> resultsNull = VRT_CTR_FleetSearch.searchVehicles(null);
        List<VRT_Vehicle__c> resultsBlank = VRT_CTR_FleetSearch.searchVehicles('   ');
        Test.stopTest();

        System.assertEquals(0, resultsNull.size(), 'Búsqueda nula debe retornar vacío.');
        System.assertEquals(0, resultsBlank.size(), 'Búsqueda vacía debe retornar vacío.');
    }

    @IsTest
    static void searchVehicles_noMatches_returnsEmpty() {
        Test.startTest();
        List<VRT_Vehicle__c> results = VRT_CTR_FleetSearch.searchVehicles('Ferrari');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Búsqueda sin coincidencias debe retornar vacío.');
    }
}
