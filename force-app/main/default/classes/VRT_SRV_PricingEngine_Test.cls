/**
 * @author      ICASTILLOF
 * @since       08/07/2026
 * @desc        Clase de test para VRT_SRV_PricingEngine.
 *              Cubre: determineSeason, calculateTotalCost (con tarifa, sin tarifa,
 *              descuento fidelidad, penalización tardía, bulk), calculateLoyaltyDiscount,
 *              calculateLatePenalty e integración end-to-end vía trigger.
 * @history     08/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
private class VRT_SRV_PricingEngine_Test {

    // ──────────────────────────────────────────────────────────────────────
    // Test Data Factory
    // ──────────────────────────────────────────────────────────────────────

    private static Integer vehicleCounter = 0;

    /**
     * @desc    Crea un vehículo válido para tests (Available=true, Status='Listo', matrícula 7 chars)
     */
    private static VRT_Vehicle__c createVehicle(String vehicleType) {
        vehicleCounter++;
        VRT_Vehicle__c vehicle = new VRT_Vehicle__c(
            VRT_TXT_Brand__c        = 'TestBrand',
            VRT_TXT_Model__c        = 'TestModel',
            VRT_SEL_VehicleType__c  = vehicleType,
            VRT_FLG_Available__c    = true,
            VRT_SEL_Status__c       = 'Listo',
            VRT_NUM_Mileage__c      = 1000,
            VRT_NUM_Usage__c        = 0,
            VRT_TXT_LicensePlate__c = 'T' + String.valueOf(vehicleCounter).leftPad(6, '0'),
            VRT_NUM_Passengers__c   = 5,
            VRT_SEL_EnergyType__c   = 'Gasolina'
        );
        return vehicle;
    }

    /**
     * @desc    Crea una tarifa activa
     */
    private static VRT_Tarifa__c createTarifa(String season, String vehicleType, Decimal pricePerDay) {
        VRT_Tarifa__c tarifa = new VRT_Tarifa__c(
            VRT_SEL_Season__c      = season,
            VRT_SEL_VehicleType__c = vehicleType,
            VRT_DIV_PricePerDay__c = pricePerDay,
            VRT_FLG_Active__c      = true
        );
        return tarifa;
    }

    /**
     * @desc    Crea un alquiler válido que pase todas las validation rules.
     *          Status='En curso', PaymentStatus='Pagado' → no dispara VRT_ReservaValida ni VRT_PagoPendienteNoInicia.
     *          InitialDate <= FinalDate → no dispara VRT_FechaInicio / VRT_FechaFinal.
     */
    private static VRT_Rental__c createRental(Id vehicleId, Id accountId, Date startDate, Date endDate) {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = 'En curso',
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );
        return rental;
    }

    // ──────────────────────────────────────────────────────────────────────
    // determineSeason – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void determineSeason_alta_junio() {
        System.assertEquals('Alta', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 6, 15)),
            'Junio debe ser temporada Alta');
    }

    @IsTest
    static void determineSeason_alta_julio() {
        System.assertEquals('Alta', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 7, 1)),
            'Julio debe ser temporada Alta');
    }

    @IsTest
    static void determineSeason_alta_agosto() {
        System.assertEquals('Alta', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 8, 20)),
            'Agosto debe ser temporada Alta');
    }

    @IsTest
    static void determineSeason_alta_diciembre() {
        System.assertEquals('Alta', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 12, 25)),
            'Diciembre debe ser temporada Alta');
    }

    @IsTest
    static void determineSeason_media_marzo() {
        System.assertEquals('Media', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 3, 10)),
            'Marzo debe ser temporada Media');
    }

    @IsTest
    static void determineSeason_media_abril() {
        System.assertEquals('Media', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 4, 5)),
            'Abril debe ser temporada Media');
    }

    @IsTest
    static void determineSeason_media_mayo() {
        System.assertEquals('Media', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 5, 1)),
            'Mayo debe ser temporada Media');
    }

    @IsTest
    static void determineSeason_media_septiembre() {
        System.assertEquals('Media', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 9, 15)),
            'Septiembre debe ser temporada Media');
    }

    @IsTest
    static void determineSeason_media_octubre() {
        System.assertEquals('Media', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 10, 31)),
            'Octubre debe ser temporada Media');
    }

    @IsTest
    static void determineSeason_baja_enero() {
        System.assertEquals('Baja', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 1, 15)),
            'Enero debe ser temporada Baja');
    }

    @IsTest
    static void determineSeason_baja_febrero() {
        System.assertEquals('Baja', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 2, 14)),
            'Febrero debe ser temporada Baja');
    }

    @IsTest
    static void determineSeason_baja_noviembre() {
        System.assertEquals('Baja', VRT_SRV_PricingEngine.determineSeason(Date.newInstance(2026, 11, 11)),
            'Noviembre debe ser temporada Baja');
    }

    @IsTest
    static void determineSeason_null_devuelveBaja() {
        System.assertEquals('Baja', VRT_SRV_PricingEngine.determineSeason(null),
            'Fecha null debe devolver Baja');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Cálculo básico con tarifa
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_basico_conTarifa() {
        // Arrange: Coche en temporada Alta, tarifa 100€/día, 5 días
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Alta', 'coche', 100.00);
        insert tarifa;

        // Julio (futuro) = temporada Alta, 5 días
        Date startDate = Date.newInstance(2027, 7, 1);
        Date endDate   = Date.newInstance(2027, 7, 6);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, startDate, endDate);

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: Re-query para obtener el valor persistido (100 * 5 = 500.00)
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(500.00, result.VRT_DIV_TotalCost__c,
            'Coste total debe ser precio/día × duración = 500.00');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Sin tarifa encontrada
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_sinTarifa_costeCero() {
        // Arrange: No insertamos tarifa para la combinación
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Fechas futuras para evitar penalización tardía
        Date startDate = Date.newInstance(2027, 7, 1);
        Date endDate   = Date.newInstance(2027, 7, 6);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, startDate, endDate);

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: Sin tarifa → precio/día = 0 → coste = 0
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(0.00, result.VRT_DIV_TotalCost__c,
            'Sin tarifa, el coste debe ser 0');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Lista null y vacía (defensivo)
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_null_noFalla() {
        Test.startTest();
        VRT_SRV_PricingEngine.calculateTotalCost(null);
        Test.stopTest();
        // Si llega aquí sin excepción, el test pasa
        System.assert(true, 'calculateTotalCost con null no debe lanzar excepción');
    }

    @IsTest
    static void calculateTotalCost_listaVacia_noFalla() {
        Test.startTest();
        VRT_SRV_PricingEngine.calculateTotalCost(new List<VRT_Rental__c>());
        Test.stopTest();
        System.assert(true, 'calculateTotalCost con lista vacía no debe lanzar excepción');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Descuento de fidelidad
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_conDescuentoFidelidad() {
        // Arrange: Cuenta con ≥3 alquileres completados en los últimos 12 meses
        Account acc = new Account(Name = 'Loyal Customer');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Alta', 'coche', 100.00);
        insert tarifa;

        // Crear 3 alquileres completados históricos para la cuenta (últimos 12 meses)
        List<VRT_Rental__c> historicRentals = new List<VRT_Rental__c>();
        for (Integer i = 0; i < 3; i++) {
            Date hStart = Date.today().addMonths(-6).addDays(i * 10);
            Date hEnd   = hStart.addDays(3);
            VRT_Rental__c hr = createRental(vehicle.Id, acc.Id, hStart, hEnd);
            hr.VRT_SEL_Status__c = 'Completado';
            historicRentals.add(hr);
        }
        insert historicRentals;

        // Alquiler nuevo: julio futuro (Alta), 10 días
        Date startDate = Date.newInstance(2027, 7, 1);
        Date endDate   = Date.newInstance(2027, 7, 11);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, startDate, endDate);

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: Base = 100 * 10 = 1000; con 5% descuento = 950.00
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(950.00, result.VRT_DIV_TotalCost__c,
            'Con descuento de fidelidad (5%), el coste debe ser 950.00');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Sin descuento (menos de 3 alquileres)
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_sinDescuentoFidelidad() {
        // Arrange: Cuenta con solo 2 alquileres completados → no llega al mínimo
        Account acc = new Account(Name = 'New Customer');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Moto');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Media', 'moto', 50.00);
        insert tarifa;

        // Solo 2 alquileres completados (por debajo del umbral de 3)
        List<VRT_Rental__c> historicRentals = new List<VRT_Rental__c>();
        for (Integer i = 0; i < 2; i++) {
            Date hStart = Date.today().addMonths(-3).addDays(i * 5);
            Date hEnd   = hStart.addDays(2);
            VRT_Rental__c hr = createRental(vehicle.Id, acc.Id, hStart, hEnd);
            hr.VRT_SEL_Status__c = 'Completado';
            historicRentals.add(hr);
        }
        insert historicRentals;

        // Alquiler en septiembre futuro (Media), 4 días
        Date startDate = Date.newInstance(2027, 9, 1);
        Date endDate   = Date.newInstance(2027, 9, 5);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, startDate, endDate);

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: 50 * 4 = 200.00 (sin descuento)
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(200.00, result.VRT_DIV_TotalCost__c,
            'Sin descuento de fidelidad, el coste debe ser 200.00');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateLatePenalty – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateLatePenalty_conRetraso() {
        // Arrange: Alquiler 'En curso' cuya fecha fin ya pasó
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DAT_FinalDate__c = Date.today().addDays(-3), // 3 días de retraso
            VRT_SEL_Status__c    = 'En curso'
        );
        Decimal pricePerDay = 100.00;

        // Act
        Decimal penalty = VRT_SRV_PricingEngine.calculateLatePenalty(rental, pricePerDay);

        // Assert: 100 * 0.25 * 3 = 75.00
        System.assertEquals(75.00, penalty,
            'Penalización debe ser 25% × precio/día × días retraso = 75.00');
    }

    @IsTest
    static void calculateLatePenalty_sinRetraso() {
        // Arrange: Alquiler 'En curso' cuya fecha fin aún no ha llegado
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DAT_FinalDate__c = Date.today().addDays(5),
            VRT_SEL_Status__c    = 'En curso'
        );

        // Act
        Decimal penalty = VRT_SRV_PricingEngine.calculateLatePenalty(rental, 100.00);

        // Assert
        System.assertEquals(0, penalty,
            'Sin retraso, la penalización debe ser 0');
    }

    @IsTest
    static void calculateLatePenalty_estadoCompletado_sinPenalizacion() {
        // Arrange: Alquiler completado, aunque fecha fin haya pasado
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DAT_FinalDate__c = Date.today().addDays(-10),
            VRT_SEL_Status__c    = 'Completado'
        );

        // Act
        Decimal penalty = VRT_SRV_PricingEngine.calculateLatePenalty(rental, 100.00);

        // Assert: No está 'En curso' → sin penalización
        System.assertEquals(0, penalty,
            'Alquiler completado no debe tener penalización');
    }

    @IsTest
    static void calculateLatePenalty_null_inputs() {
        // Rental null
        System.assertEquals(0, VRT_SRV_PricingEngine.calculateLatePenalty(null, 100.00),
            'Rental null debe devolver 0');

        // Fecha fin null
        VRT_Rental__c rental = new VRT_Rental__c(VRT_SEL_Status__c = 'En curso');
        System.assertEquals(0, VRT_SRV_PricingEngine.calculateLatePenalty(rental, 100.00),
            'Fecha fin null debe devolver 0');

        // PricePerDay null
        VRT_Rental__c rental2 = new VRT_Rental__c(
            VRT_DAT_FinalDate__c = Date.today().addDays(-2),
            VRT_SEL_Status__c    = 'En curso'
        );
        System.assertEquals(0, VRT_SRV_PricingEngine.calculateLatePenalty(rental2, null),
            'PricePerDay null debe devolver 0');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateLoyaltyDiscount – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateLoyaltyDiscount_elegible() {
        Account acc = new Account(Name = 'Loyal');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Crear 4 alquileres completados en los últimos 12 meses
        List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();
        for (Integer i = 0; i < 4; i++) {
            Date hStart = Date.today().addMonths(-6).addDays(i * 10);
            Date hEnd   = hStart.addDays(3);
            VRT_Rental__c r = createRental(vehicle.Id, acc.Id, hStart, hEnd);
            r.VRT_SEL_Status__c = 'Completado';
            rentals.add(r);
        }
        insert rentals;

        // Act
        Test.startTest();
        Map<Id, Boolean> result = VRT_SRV_PricingEngine.calculateLoyaltyDiscount(
            new Set<Id>{ acc.Id }
        );
        Test.stopTest();

        // Assert
        System.assertEquals(true, result.get(acc.Id),
            'Cuenta con ≥3 alquileres completados debe ser elegible');
    }

    @IsTest
    static void calculateLoyaltyDiscount_noElegible() {
        Account acc = new Account(Name = 'Nuevo');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Solo 1 alquiler completado
        Date hStart = Date.today().addMonths(-3);
        Date hEnd   = hStart.addDays(2);
        VRT_Rental__c r = createRental(vehicle.Id, acc.Id, hStart, hEnd);
        r.VRT_SEL_Status__c = 'Completado';
        insert r;

        // Act
        Test.startTest();
        Map<Id, Boolean> result = VRT_SRV_PricingEngine.calculateLoyaltyDiscount(
            new Set<Id>{ acc.Id }
        );
        Test.stopTest();

        // Assert
        System.assertEquals(false, result.get(acc.Id),
            'Cuenta con <3 alquileres no debe ser elegible');
    }

    @IsTest
    static void calculateLoyaltyDiscount_setNull_devuelveMapVacio() {
        Map<Id, Boolean> result = VRT_SRV_PricingEngine.calculateLoyaltyDiscount(null);
        System.assertEquals(0, result.size(),
            'Set null debe devolver map vacío');
    }

    @IsTest
    static void calculateLoyaltyDiscount_setVacio_devuelveMapVacio() {
        Map<Id, Boolean> result = VRT_SRV_PricingEngine.calculateLoyaltyDiscount(new Set<Id>());
        System.assertEquals(0, result.size(),
            'Set vacío debe devolver map vacío');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Procesamiento Bulk
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_bulk_200registros() {
        // Arrange
        Account acc = new Account(Name = 'Bulk Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Baja', 'coche', 40.00);
        insert tarifa;

        // Enero futuro = temporada Baja, 2 días de duración
        Date startDate = Date.newInstance(2027, 1, 10);
        Date endDate   = Date.newInstance(2027, 1, 12);

        List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();
        for (Integer i = 0; i < 200; i++) {
            rentals.add(createRental(vehicle.Id, acc.Id, startDate, endDate));
        }

        // Act: insert bulk dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rentals;
        Test.stopTest();

        // Assert: 40 * 2 = 80.00 para cada registro
        List<VRT_Rental__c> results = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id IN :rentals];
        for (VRT_Rental__c result : results) {
            System.assertEquals(80.00, result.VRT_DIV_TotalCost__c,
                'Cada registro bulk debe tener coste = 80.00');
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Diferentes temporadas y tipos de vehículo
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_moto_temporadaMedia() {
        Account acc = new Account(Name = 'Moto Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Moto');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Media', 'moto', 30.00);
        insert tarifa;

        // Abril futuro = temporada Media, 7 días
        Date startDate = Date.newInstance(2027, 4, 1);
        Date endDate   = Date.newInstance(2027, 4, 8);

        VRT_Rental__c rental = createRental(vehicle.Id, acc.Id, startDate, endDate);

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: 30 * 7 = 210.00
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(210.00, result.VRT_DIV_TotalCost__c,
            'Moto en temporada Media, 7 días: 30 × 7 = 210.00');
    }

    // ──────────────────────────────────────────────────────────────────────
    // calculateTotalCost – Sin vehículo asignado
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void calculateTotalCost_sinVehiculo_costeCero() {
        Account acc = new Account(Name = 'No Vehicle Account');
        insert acc;

        VRT_Tarifa__c tarifa = createTarifa('Alta', 'coche', 100.00);
        insert tarifa;

        // Rental sin vehículo, fechas futuras
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_LKP_Account__c       = acc.Id,
            VRT_DAT_InitialDate__c   = Date.newInstance(2027, 7, 1),
            VRT_DAT_FinalDate__c     = Date.newInstance(2027, 7, 6),
            VRT_SEL_Status__c        = 'En curso',
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );

        // Act: insert dispara trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Sin vehículo → no se puede resolver tipo → no hay tarifa → coste 0
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(0.00, result.VRT_DIV_TotalCost__c,
            'Sin vehículo asignado, el coste debe ser 0');
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración end-to-end – Insert via trigger
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void integracion_insertRental_calculaPrecio() {
        // Arrange
        Account acc = new Account(Name = 'Integration Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Tarifa__c tarifa = createTarifa('Alta', 'coche', 80.00);
        insert tarifa;

        // Agosto = temporada Alta, 3 días
        VRT_Rental__c rental = createRental(
            vehicle.Id, acc.Id,
            Date.newInstance(2026, 8, 1),
            Date.newInstance(2026, 8, 4)
        );

        // Act: el insert dispara el trigger → before insert → calculateTotalCost
        Test.startTest();
        insert rental;
        Test.stopTest();

        // Assert: Re-query para verificar el valor persistido
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        // 80 * 3 = 240.00
        System.assertEquals(240.00, result.VRT_DIV_TotalCost__c,
            'El trigger debe calcular el coste total en before insert: 80 × 3 = 240.00');
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración end-to-end – Update via trigger (recalcula precio)
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void integracion_updateRental_recalculaPrecio() {
        // Arrange
        Account acc = new Account(Name = 'Update Account');
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        VRT_Tarifa__c tarifaAlta = createTarifa('Alta', 'coche', 100.00);
        VRT_Tarifa__c tarifaBaja = createTarifa('Baja', 'coche', 40.00);
        insert new List<VRT_Tarifa__c>{ tarifaAlta, tarifaBaja };

        // Insert inicial en agosto futuro (Alta): 100 * 5 = 500
        VRT_Rental__c rental = createRental(
            vehicle.Id, acc.Id,
            Date.newInstance(2027, 8, 1),
            Date.newInstance(2027, 8, 6)
        );
        insert rental;

        // Act: Cambiar fechas a enero futuro (Baja), 10 días → debe recalcular
        rental.VRT_DAT_InitialDate__c = Date.newInstance(2027, 1, 5);
        rental.VRT_DAT_FinalDate__c   = Date.newInstance(2027, 1, 15);

        Test.startTest();
        update rental;
        Test.stopTest();

        // Assert: 40 * 10 = 400.00
        VRT_Rental__c result = [SELECT VRT_DIV_TotalCost__c FROM VRT_Rental__c WHERE Id = :rental.Id];
        System.assertEquals(400.00, result.VRT_DIV_TotalCost__c,
            'Tras update de fechas, el coste debe recalcularse: 40 × 10 = 400.00');
    }
}
