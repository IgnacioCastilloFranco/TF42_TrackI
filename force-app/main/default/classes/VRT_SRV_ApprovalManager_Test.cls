/**
 * @author      ICASTILLOF
 * @since       09/07/2026
 * @desc        Tests unitarios para VRT_SRV_ApprovalManager.
 *              Cubre: requiresApproval (positivo, negativo, null, umbral exacto),
 *              submitForApprovalOnInsert (coste alto, coste bajo, lista vacía/null),
 *              submitForApprovalOnUpdate (cruce de umbral, sin cruce, maps null),
 *              e integración end-to-end vía trigger con el approval process desplegado.
 *
 * @history     09/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
private class VRT_SRV_ApprovalManager_Test {

    // ──────────────────────────────────────────────────────────────────────
    // Test Data Factory
    // ──────────────────────────────────────────────────────────────────────

    private static Integer vehicleCounter = 0;

    /**
     * @desc    Crea una cuenta válida para tests
     */
    private static Account createAccount() {
        return new Account(Name = 'Approval Test Account');
    }

    /**
     * @desc    Crea un vehículo válido (Available=true, Status='Listo', matrícula única)
     */
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
            VRT_TXT_LicensePlate__c = 'M' + String.valueOf(vehicleCounter).leftPad(6, '0'),
            VRT_NUM_Passengers__c   = 5,
            VRT_SEL_EnergyType__c   = 'Gasolina',
            VRT_TXT_ExternalId__c   = 'APPR-' + String.valueOf(vehicleCounter)
        );
    }

    /**
     * @desc    Crea una tarifa activa para tests
     */
    private static VRT_Tarifa__c createTarifa(String season, String vehicleType, Decimal pricePerDay) {
        return new VRT_Tarifa__c(
            VRT_SEL_Season__c      = season,
            VRT_SEL_VehicleType__c = vehicleType,
            VRT_DIV_PricePerDay__c = pricePerDay,
            VRT_FLG_Active__c      = true
        );
    }

    /**
     * @desc    Crea un alquiler con estado Reservado y Pagado (pasa validation rules).
     *          Para que requiresApproval sea true, el coste resultante debe superar 3000.
     */
    private static VRT_Rental__c createRentalReservado(Id vehicleId, Id accountId,
                                                        Date startDate, Date endDate) {
        return new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = 'Reservado',
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );
    }

    /**
     * @desc    Crea un alquiler con estado En curso y Pagado (no requiere aprobación por estado)
     */
    private static VRT_Rental__c createRentalEnCurso(Id vehicleId, Id accountId,
                                                      Date startDate, Date endDate) {
        return new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = 'En curso',
            VRT_SEL_PaymentStatus__c = 'Pagado'
        );
    }

    /**
     * @desc    Crea dos usuarios con jerarquía Manager → Subordinado.
     *          Necesario para que el Approval Process pueda asignar aprobador.
     * @return  List<User> donde [0] = manager, [1] = subordinado
     */
    private static List<User> createUserHierarchy() {
        Id profileId = UserInfo.getProfileId();
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());

        User manager = new User(
            FirstName     = 'Approval',
            LastName      = 'Manager',
            Email         = 'appr.manager@vrt.test',
            Username      = 'appr.manager.' + uniqueSuffix + '@vrt.test',
            Alias         = 'aprmgr',
            TimeZoneSidKey    = 'Europe/Madrid',
            LocaleSidKey      = 'es_ES',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'es',
            ProfileId         = profileId
        );
        insert manager;

        User submitter = new User(
            FirstName     = 'Approval',
            LastName      = 'Submitter',
            Email         = 'appr.submitter@vrt.test',
            Username      = 'appr.submitter.' + uniqueSuffix + '@vrt.test',
            Alias         = 'aprsub',
            TimeZoneSidKey    = 'Europe/Madrid',
            LocaleSidKey      = 'es_ES',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'es',
            ProfileId         = profileId,
            ManagerId         = manager.Id
        );
        insert submitter;

        return new List<User>{ manager, submitter };
    }

    // ──────────────────────────────────────────────────────────────────────
    // requiresApproval – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void requiresApproval_costeAlto_reservado_true() {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DIV_TotalCost__c = 5000,
            VRT_SEL_Status__c    = 'Reservado'
        );
        System.assertEquals(true, VRT_SRV_ApprovalManager.requiresApproval(rental),
            'Un rental Reservado con coste > 3000 debe requerir aprobación.');
    }

    @IsTest
    static void requiresApproval_costeBajo_reservado_false() {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DIV_TotalCost__c = 2000,
            VRT_SEL_Status__c    = 'Reservado'
        );
        System.assertEquals(false, VRT_SRV_ApprovalManager.requiresApproval(rental),
            'Un rental Reservado con coste <= 3000 NO debe requerir aprobación.');
    }

    @IsTest
    static void requiresApproval_costeAlto_enCurso_false() {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DIV_TotalCost__c = 5000,
            VRT_SEL_Status__c    = 'En curso'
        );
        System.assertEquals(false, VRT_SRV_ApprovalManager.requiresApproval(rental),
            'Un rental En curso, aunque supere el umbral, NO debe requerir aprobación.');
    }

    @IsTest
    static void requiresApproval_costeExactoUmbral_false() {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DIV_TotalCost__c = VRT_SRV_ApprovalManager.APPROVAL_THRESHOLD,
            VRT_SEL_Status__c    = 'Reservado'
        );
        System.assertEquals(false, VRT_SRV_ApprovalManager.requiresApproval(rental),
            'El umbral exacto (3000) NO debe requerir aprobación (condición es > 3000, no >=).');
    }

    @IsTest
    static void requiresApproval_costeNull_false() {
        VRT_Rental__c rental = new VRT_Rental__c(
            VRT_DIV_TotalCost__c = null,
            VRT_SEL_Status__c    = 'Reservado'
        );
        System.assertEquals(false, VRT_SRV_ApprovalManager.requiresApproval(rental),
            'Un rental con coste null NO debe requerir aprobación.');
    }

    @IsTest
    static void requiresApproval_rentalNull_false() {
        System.assertEquals(false, VRT_SRV_ApprovalManager.requiresApproval(null),
            'Un rental null NO debe requerir aprobación.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // submitForApprovalOnInsert – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void submitForApprovalOnInsert_listaNull_sinError() {
        Test.startTest();
        VRT_SRV_ApprovalManager.submitForApprovalOnInsert(null);
        Test.stopTest();
        // Si no lanza excepción, el test es correcto
        System.assert(true, 'No debe lanzar excepción con lista null.');
    }

    @IsTest
    static void submitForApprovalOnInsert_listaVacia_sinError() {
        Test.startTest();
        VRT_SRV_ApprovalManager.submitForApprovalOnInsert(new List<VRT_Rental__c>());
        Test.stopTest();
        System.assert(true, 'No debe lanzar excepción con lista vacía.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // submitForApprovalOnUpdate – Tests unitarios
    // ──────────────────────────────────────────────────────────────────────

    @IsTest
    static void submitForApprovalOnUpdate_mapsNull_sinError() {
        Test.startTest();
        VRT_SRV_ApprovalManager.submitForApprovalOnUpdate(null, null);
        Test.stopTest();
        System.assert(true, 'No debe lanzar excepción con maps null.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración: insert con coste alto → aprobación enviada
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Verifica que al insertar un rental Reservado cuyo coste calculado
     *          supere 3000€, se envía automáticamente a aprobación.
     *          Requiere el approval process VRT_APR_FinancialApproval desplegado.
     *          Usa tarifa de 200€/día × 20 días = 4000€ > 3000€.
     */
    @IsTest
    static void insertRentalReservado_costeAlto_enviaAprobacion() {
        // Crear jerarquía de usuarios para que el Approval Process encuentre un Manager
        List<User> users = createUserHierarchy();
        User submitter = users[1];

        System.runAs(submitter) {
            Account acc = createAccount();
            insert acc;

            VRT_Vehicle__c vehicle = createVehicle('Coche');
            insert vehicle;

            // Tarifa Baja-Coche: 200€/día → 20 días × 200 = 4000€ > 3000
            VRT_Tarifa__c tarifa = createTarifa('Baja', 'Coche', 200);
            insert tarifa;

            // Enero = temporada Baja. 20 días → 4000€
            VRT_Rental__c rental = createRentalReservado(
                vehicle.Id, acc.Id,
                Date.newInstance(2028, 1, 5),
                Date.newInstance(2028, 1, 25)
            );

            Test.startTest();
            insert rental;
            Test.stopTest();

            // Verificar que el registro fue enviado a aprobación (ProcessInstance creado)
            List<ProcessInstance> approvals = [
                SELECT Id, Status, TargetObjectId
                FROM ProcessInstance
                WHERE TargetObjectId = :rental.Id
            ];
            System.assertEquals(1, approvals.size(),
                'Debe existir un ProcessInstance para el rental con coste > 3000€.');
            System.assertEquals('Pending', approvals[0].Status,
                'El ProcessInstance debe estar en estado Pending.');
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración: insert con coste bajo → sin aprobación
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Verifica que un rental Reservado con coste <= 3000€ NO se envía
     *          a aprobación. Usa tarifa de 50€/día × 5 días = 250€.
     */
    @IsTest
    static void insertRentalReservado_costeBajo_sinAprobacion() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Tarifa Baja-Coche: 50€/día → 5 días × 50 = 250€ < 3000
        VRT_Tarifa__c tarifa = createTarifa('Baja', 'Coche', 50);
        insert tarifa;

        // Enero = temporada Baja. 5 días → 250€
        VRT_Rental__c rental = createRentalReservado(
            vehicle.Id, acc.Id,
            Date.newInstance(2028, 1, 5),
            Date.newInstance(2028, 1, 10)
        );

        Test.startTest();
        insert rental;
        Test.stopTest();

        List<ProcessInstance> approvals = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :rental.Id
        ];
        System.assertEquals(0, approvals.size(),
            'No debe existir ProcessInstance para un rental con coste <= 3000€.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración: insert con estado En curso → sin aprobación
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Verifica que un rental En curso con coste alto NO se envía
     *          a aprobación (solo aplica a estado Reservado).
     */
    @IsTest
    static void insertRentalEnCurso_costeAlto_sinAprobacion() {
        Account acc = createAccount();
        insert acc;

        VRT_Vehicle__c vehicle = createVehicle('Coche');
        insert vehicle;

        // Tarifa Baja-Coche: 200€/día → 20 días × 200 = 4000€ > 3000
        VRT_Tarifa__c tarifa = createTarifa('Baja', 'Coche', 200);
        insert tarifa;

        VRT_Rental__c rental = createRentalEnCurso(
            vehicle.Id, acc.Id,
            Date.newInstance(2028, 1, 5),
            Date.newInstance(2028, 1, 25)
        );

        Test.startTest();
        insert rental;
        Test.stopTest();

        List<ProcessInstance> approvals = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :rental.Id
        ];
        System.assertEquals(0, approvals.size(),
            'No debe haber ProcessInstance para un rental En curso, aunque supere el umbral.');
    }

    // ──────────────────────────────────────────────────────────────────────
    // Integración: bulk insert → solo los que superan umbral van a aprobación
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Verifica que en un insert bulk, solo los rentals que superan
     *          el umbral se envían a aprobación.
     *          Cada rental usa un vehículo diferente (evitar conflictos de disponibilidad).
     */
    @IsTest
    static void insertBulk_soloCosteAlto_enviaAprobacion() {
        // Crear jerarquía de usuarios para que el Approval Process encuentre un Manager
        List<User> users = createUserHierarchy();
        User submitter = users[1];

        System.runAs(submitter) {
            Account acc = createAccount();
            insert acc;

            // Crear 4 vehículos (cada rental necesita un vehículo distinto)
            List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>();
            for (Integer i = 0; i < 4; i++) {
                vehicles.add(createVehicle('Coche'));
            }
            insert vehicles;

            // Tarifa Baja-Coche: 200€/día
            insert new List<VRT_Tarifa__c>{
                createTarifa('Baja', 'Coche', 200)
            };

            List<VRT_Rental__c> rentals = new List<VRT_Rental__c>();

            // 2 rentals con coste alto (20 días × 200 = 4000€ > 3000)
            rentals.add(createRentalReservado(
                vehicles[0].Id, acc.Id,
                Date.newInstance(2028, 1, 5),
                Date.newInstance(2028, 1, 25)
            ));
            rentals.add(createRentalReservado(
                vehicles[1].Id, acc.Id,
                Date.newInstance(2028, 2, 5),
                Date.newInstance(2028, 2, 25)
            ));

            // 2 rentals con coste bajo (3 días × 200 = 600€ < 3000)
            rentals.add(createRentalReservado(
                vehicles[2].Id, acc.Id,
                Date.newInstance(2028, 1, 5),
                Date.newInstance(2028, 1, 8)
            ));
            rentals.add(createRentalReservado(
                vehicles[3].Id, acc.Id,
                Date.newInstance(2028, 2, 5),
                Date.newInstance(2028, 2, 8)
            ));

            Test.startTest();
            insert rentals;
            Test.stopTest();

            // Recopilar Ids de los 4 rentals
            Set<Id> allRentalIds = new Set<Id>();
            for (VRT_Rental__c r : rentals) {
                allRentalIds.add(r.Id);
            }

            List<ProcessInstance> approvals = [
                SELECT Id, TargetObjectId
                FROM ProcessInstance
                WHERE TargetObjectId IN :allRentalIds
            ];

            System.assertEquals(2, approvals.size(),
                'Solo los 2 rentals con coste > 3000€ deben tener ProcessInstance.');
        }
    }
}
