/**
 * @author      ICASTILLOF
 * @since       09/07/2026
 * @desc        Tests unitarios para VRT_SRV_AvailabilityChecker.
 *              Cubre: sin solapamiento, solapamiento con existente, caso límite
 *              mismo día fin/inicio, conflicto intra-batch y escenario bulk.
 */
@IsTest
private class VRT_SRV_AvailabilityChecker_Test {

    private static Integer vehicleCounter = 0;

    private static Account createAccount() {
        return new Account(Name = 'Availability Test Account');
    }

    private static VRT_Vehicle__c createVehicle(String vehicleType) {
        vehicleCounter++;
        return new VRT_Vehicle__c(
            VRT_TXT_Brand__c        = 'TestBrand',
            VRT_TXT_Model__c        = 'TestModel',
            VRT_SEL_VehicleType__c  = vehicleType,
            VRT_FLG_Available__c    = true,
            VRT_SEL_Status__c       = 'Listo',
            VRT_NUM_Mileage__c      = 1000,
            VRT_NUM_Usage__c        = 0,
            VRT_TXT_LicensePlate__c = 'A' + String.valueOf(vehicleCounter).leftPad(6, '0'),
            VRT_NUM_Passengers__c   = 5,
            VRT_SEL_EnergyType__c   = 'Gasolina',
            VRT_TXT_ExternalId__c   = 'AVAIL-' + String.valueOf(vehicleCounter)
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

    @IsTest
    static void validateAvailability_sinSolapamiento_ok() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        insert createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 1, 1),
            Date.newInstance(2027, 1, 5)
        );

        VRT_Rental__c secondRental = createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 1, 6),
            Date.newInstance(2027, 1, 10)
        );

        Test.startTest();
        insert secondRental;
        Test.stopTest();

        Integer countRentals = [
            SELECT COUNT()
            FROM VRT_Rental__c
            WHERE VRT_LKP_Vehicle__c = :vehicle.Id
        ];
        System.assertEquals(2, countRentals, 'Ambos alquileres no solapados deben guardarse.');
    }

    @IsTest
    static void validateAvailability_conSolapamientoExistente_addError() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        insert createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 2, 10),
            Date.newInstance(2027, 2, 15)
        );

        VRT_Rental__c overlappingRental = createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 2, 12),
            Date.newInstance(2027, 2, 14)
        );

        Test.startTest();
        try {
            insert overlappingRental;
            System.assert(false, 'El insert debía fallar por solapamiento con un alquiler existente.');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Conflicto de disponibilidad'),
                'Debe devolver error de conflicto de disponibilidad. Mensaje: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void validateAvailability_mismoDiaFinInicio_ok() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        insert createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 3, 1),
            Date.newInstance(2027, 3, 5)
        );

        VRT_Rental__c boundaryRental = createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 3, 5),
            Date.newInstance(2027, 3, 8)
        );

        Test.startTest();
        insert boundaryRental;
        Test.stopTest();

        Integer countRentals = [
            SELECT COUNT()
            FROM VRT_Rental__c
            WHERE VRT_LKP_Vehicle__c = :vehicle.Id
        ];
        System.assertEquals(2, countRentals, 'Debe permitirse fin/inicio en el mismo día.');
    }

    @IsTest
    static void validateAvailability_conflictoIntraBatch_addError() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Rental__c r1 = createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 4, 1),
            Date.newInstance(2027, 4, 6)
        );
        VRT_Rental__c r2 = createRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2027, 4, 4),
            Date.newInstance(2027, 4, 8)
        );

        Test.startTest();
        Database.SaveResult[] results = Database.insert(new List<VRT_Rental__c>{ r1, r2 }, false);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Se esperan dos resultados de inserción.');
        System.assertEquals(false, results[0].isSuccess(), 'El primer registro debe fallar por solapamiento intra-batch.');
        System.assertEquals(false, results[1].isSuccess(), 'El segundo registro debe fallar por solapamiento intra-batch.');
        System.assert(
            results[0].getErrors()[0].getMessage().contains('Conflicto intra-batch')
                || results[0].getErrors()[0].getMessage().contains('Conflicto de disponibilidad'),
            'El error debe indicar conflicto de disponibilidad. Mensaje: ' + results[0].getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void validateAvailability_bulk_ok() {
        Account acc = createAccount();
        insert acc;

        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();
        for (Integer i = 0; i < 10; i++) {
            vehicles.add(createVehicle('Coche'));
        }
        insert vehicles;

        Date baseDate = Date.newInstance(2027, 5, 1);
        List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();

        for (Integer i = 0; i < 200; i++) {
            Id vehicleId = vehicles[Math.mod(i, vehicles.size())].Id;
            Integer slot = i / vehicles.size();
            Date startDate = baseDate.addDays(slot * 3);
            Date endDate = startDate.addDays(2);

            rentals.add(createRental(vehicleId, acc.Id, startDate, endDate));
        }

        Test.startTest();
        Database.SaveResult[] results = Database.insert(rentals, false);
        Test.stopTest();

        Integer successCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            }
        }

        System.assertEquals(200, successCount, 'En el escenario bulk sin solapamientos deben insertarse los 200 alquileres.');
    }
}
