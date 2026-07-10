/**
 * @author      ICASTILLOF
 * @since       09/07/2026
 * @desc        Tests unitarios para VRT_CTR_RentalConsole.
 *              Cubre: getRentalsByAccount (con datos, sin datos, id null),
 *              getRentalSummary (KPIs correctos, sin datos, id null).
 *
 * @history     09/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
private class VRT_CTR_RentalConsole_Test {

    // ──────────────────────────────────────────────────────────────────────
    // Test Data Factory
    // ──────────────────────────────────────────────────────────────────────

    private static Integer vehicleCounter = 0;

    private static Account createAccount() {
        return new Account(Name = 'Console Test Account');
    }

    private static VRT_Vehicle__c createVehicle(String vehicleType) {
        vehicleCounter++;
        return new VRT_Vehicle__c(
            VRT_TXT_Brand__c        = 'Toyota',
            VRT_TXT_Model__c        = 'Corolla',
            VRT_SEL_VehicleType__c  = vehicleType,
            VRT_FLG_Available__c    = true,
            VRT_SEL_Status__c       = 'Listo',
            VRT_NUM_Mileage__c      = 1000,
            VRT_NUM_Usage__c        = 0,
            VRT_TXT_LicensePlate__c = 'C' + String.valueOf(vehicleCounter).leftPad(6, '0'),
            VRT_NUM_Passengers__c   = 5,
            VRT_SEL_EnergyType__c   = 'Gasolina',
            VRT_TXT_ExternalId__c   = 'CONS-' + String.valueOf(vehicleCounter)
        );
    }

    private static VRT_Tarifa__c createTarifa(String season, String vehicleType, Decimal pricePerDay) {
        return new VRT_Tarifa__c(
            VRT_SEL_Season__c      = season,
            VRT_SEL_VehicleType__c = vehicleType,
            VRT_DIV_PricePerDay__c = pricePerDay,
            VRT_FLG_Active__c      = true
        );
    }

    private static VRT_Rental__c createRental(Id vehicleId, Id accountId,
                                               Date startDate, Date endDate,
                                               String status) {
        return new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = status,
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );
    }

    // ──────────────────────────────────────────────────────────────────────
    // getRentalsByAccount – Tests
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void getRentalsByAccount_conDatos_devuelveLista() {
        Account acc = createAccount();
        insert acc;

        // Crear 3 vehículos distintos para evitar conflictos de disponibilidad
        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();
        for (Integer i = 0; i < 3; i++) {
            vehicles.add(createVehicle('Coche'));
        }
        insert vehicles;

        // Tarifa para que el pricing engine calcule
        insert createTarifa('Baja', 'Coche', 50);

        // Crear 3 alquileres con fechas no solapadas
        List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();
        rentals.add(createRental(vehicles[0].Id, acc.Id,
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 5), 'En curso'));
        rentals.add(createRental(vehicles[1].Id, acc.Id,
            Date.newInstance(2028, 2, 1), Date.newInstance(2028, 2, 5), 'Completado'));
        rentals.add(createRental(vehicles[2].Id, acc.Id,
            Date.newInstance(2028, 1, 10), Date.newInstance(2028, 1, 15), 'Reservado'));
        insert rentals;

        Test.startTest();
        List<VRT_Rental__c> result = VRT_CTR_RentalConsole.getRentalsByAccount(acc.Id);
        Test.stopTest();

        System.assertEquals(3, result.size(),
            'Debe devolver los 3 alquileres de la cuenta.');

        // Verificar que incluye datos del vehículo relacionado
        for (VRT_Rental__c r : result) {
            System.assertNotEquals(null, r.VRT_LKP_Vehicle__r,
                'Debe incluir la relación con el vehículo.');
            System.assertNotEquals(null, r.VRT_LKP_Vehicle__r.VRT_TXT_Brand__c,
                'Debe incluir la marca del vehículo.');
        }
    }

    @IsTest
    static void getRentalsByAccount_sinDatos_devuelveListaVacia() {
        Account acc = createAccount();
        insert acc;

        Test.startTest();
        List<VRT_Rental__c> result = VRT_CTR_RentalConsole.getRentalsByAccount(acc.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Debe devolver lista vacía para cuenta sin alquileres.');
    }

    @IsTest
    static void getRentalsByAccount_idNull_devuelveListaVacia() {
        Test.startTest();
        List<VRT_Rental__c> result = VRT_CTR_RentalConsole.getRentalsByAccount(null);
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Debe devolver lista vacía con Id null.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // getRentalSummary – Tests
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void getRentalSummary_conDatos_KPIsCorrectos() {
        Account acc = createAccount();
        insert acc;

        // Crear 4 vehículos distintos
        List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();
        for (Integer i = 0; i < 4; i++) {
            vehicles.add(createVehicle('Coche'));
        }
        insert vehicles;

        // Tarifa Baja-Coche: 100€/día
        insert createTarifa('Baja', 'Coche', 100);

        // Crear alquileres con distintos estados (fechas no solapadas, vehículos distintos)
        List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();
        // 2 En curso (5 días × 100 = 500€ cada uno)
        rentals.add(createRental(vehicles[0].Id, acc.Id,
            Date.newInstance(2028, 1, 1), Date.newInstance(2028, 1, 6), 'En curso'));
        rentals.add(createRental(vehicles[1].Id, acc.Id,
            Date.newInstance(2028, 2, 1), Date.newInstance(2028, 2, 6), 'En curso'));
        // 1 Completado (5 días × 100 = 500€)
        rentals.add(createRental(vehicles[2].Id, acc.Id,
            Date.newInstance(2028, 1, 10), Date.newInstance(2028, 1, 15), 'Completado'));
        // 1 Cancelado (5 días × 100 = 500€)
        rentals.add(createRental(vehicles[3].Id, acc.Id,
            Date.newInstance(2028, 2, 10), Date.newInstance(2028, 2, 15), 'Cancelado'));
        insert rentals;

        Test.startTest();
        VRT_CTR_RentalConsole.RentalSummary summary =
            VRT_CTR_RentalConsole.getRentalSummary(acc.Id);
        Test.stopTest();

        System.assertEquals(4, summary.totalRentals,
            'totalRentals debe ser 4.');
        System.assertEquals(2, summary.activeRentals,
            'activeRentals debe ser 2 (En curso).');
        System.assertEquals(1, summary.completedRentals,
            'completedRentals debe ser 1.');
        System.assertEquals(1, summary.cancelledRentals,
            'cancelledRentals debe ser 1.');
        System.assert(summary.totalCost > 0,
            'totalCost debe ser mayor que 0.');
    }

    @IsTest
    static void getRentalSummary_sinDatos_todoCero() {
        Account acc = createAccount();
        insert acc;

        Test.startTest();
        VRT_CTR_RentalConsole.RentalSummary summary =
            VRT_CTR_RentalConsole.getRentalSummary(acc.Id);
        Test.stopTest();

        System.assertEquals(0, summary.totalRentals,
            'totalRentals debe ser 0 sin alquileres.');
        System.assertEquals(0, summary.activeRentals,
            'activeRentals debe ser 0.');
        System.assertEquals(0, summary.completedRentals,
            'completedRentals debe ser 0.');
        System.assertEquals(0, summary.cancelledRentals,
            'cancelledRentals debe ser 0.');
        System.assertEquals(0, summary.totalCost,
            'totalCost debe ser 0.');
    }

    @IsTest
    static void getRentalSummary_idNull_todoCero() {
        Test.startTest();
        VRT_CTR_RentalConsole.RentalSummary summary =
            VRT_CTR_RentalConsole.getRentalSummary(null);
        Test.stopTest();

        System.assertEquals(0, summary.totalRentals,
            'totalRentals debe ser 0 con Id null.');
        System.assertEquals(0, summary.totalCost,
            'totalCost debe ser 0 con Id null.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // simulateAndValidateRental – Tests
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void simulateAndValidateRental_disponible_calculaPrecio() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Tarifa Baja-Coche: 100€/día
        insert createTarifa('Baja', 'Coche', 100);

        Test.startTest();
        // Enero = temporada Baja. 5 días → 500€
        VRT_CTR_RentalConsole.SimulationResult result = VRT_CTR_RentalConsole.simulateAndValidateRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2028, 1, 10),
            Date.newInstance(2028, 1, 15)
        );
        Test.stopTest();

        System.assertEquals(true, result.isAvailable, 'El vehículo debe estar disponible.');
        System.assertEquals(500.0, result.price, 'El precio debe ser 500€ (5 días × 100€/día).');
        System.assertEquals(null, result.errorMessage, 'No debe haber mensaje de error.');
    }

    @IsTest
    static void simulateAndValidateRental_conSolapamiento_noDisponible() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Tarifa Baja-Coche: 100€/día
        insert createTarifa('Baja', 'Coche', 100);

        // Crear alquiler existente
        VRT_Rental__c existing = createRental(vehicle.Id, acc.Id,
            Date.newInstance(2028, 1, 10), Date.newInstance(2028, 1, 15), 'Reservado');
        insert existing;

        Test.startTest();
        // Solapamiento total
        VRT_CTR_RentalConsole.SimulationResult result = VRT_CTR_RentalConsole.simulateAndValidateRental(
            vehicle.Id,
            acc.Id,
            Date.newInstance(2028, 1, 12),
            Date.newInstance(2028, 1, 14)
        );
        Test.stopTest();

        System.assertEquals(false, result.isAvailable, 'El vehículo no debe estar disponible.');
        System.assertNotEquals(null, result.errorMessage, 'Debe haber un mensaje de error.');
        System.assert(result.errorMessage.contains('Conflicto de disponibilidad'),
            'El mensaje de error debe indicar conflicto de disponibilidad. Recibido: ' + result.errorMessage);
    }

    @IsTest
    static void simulateAndValidateRental_datosNull_error() {
        Test.startTest();
        VRT_CTR_RentalConsole.SimulationResult result = VRT_CTR_RentalConsole.simulateAndValidateRental(
            null, null, null, null
        );
        Test.stopTest();

        System.assertEquals(true, result.isAvailable, 'Por defecto se asume disponible.');
        System.assertNotEquals(null, result.errorMessage, 'Debe haber un mensaje de error por campos incompletos.');
    }
}
