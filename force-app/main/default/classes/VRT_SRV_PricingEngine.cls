/**
 * @author      ICASTILLOF
 * @since       06/07/2026
 * @desc        Clase Service con la lógica de cálculo de precios para alquileres.
 *              Incluye determinación de temporada, búsqueda de tarifa, descuento
 *              de fidelidad y penalización por devolución tardía.
 * @history     06/07/2026 - ICASTILLOF - Creación de la clase
 */
public with sharing class VRT_SRV_PricingEngine {

    // ──────────────────────────────────────────────────────────────────────
    // Constantes
    // ──────────────────────────────────────────────────────────────────────

    /** Porcentaje de descuento por fidelidad (5%) */
    private static final Decimal LOYALTY_DISCOUNT_PERCENT = 0.05;

    /** Número mínimo de alquileres en los últimos 12 meses para obtener descuento */
    private static final Integer LOYALTY_MIN_RENTALS = 3;

    /** Porcentaje de penalización diaria por devolución tardía (25%) */
    private static final Decimal LATE_PENALTY_PERCENT = 0.25;

    // ──────────────────────────────────────────────────────────────────────
    // Método principal bulk
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Método principal bulk que calcula el coste total de cada alquiler.
     *          Fórmula: CostBase = PrecioTarifa × Duración
     *          - Se aplica descuento de fidelidad si corresponde (5%)
     *          - Se añade penalización por devolución tardía si corresponde (25%/día)
     *          El resultado se escribe en VRT_DIV_TotalCost__c de cada registro.
     * @param   rentals Lista de VRT_Rental__c a procesar (deben tener los campos
     *          VRT_DAT_InitialDate__c, VRT_DAT_FinalDate__c, VRT_FOR_Duration__c,
     *          VRT_LKP_Account__c y VRT_LKP_Vehicle__c informados).
     */
    public static void calculateTotalCost(List<VRT_Rental__c> rentals) {
        if (rentals == null || rentals.isEmpty()) {
            return;
        }

        // 1. Recopilar Ids de vehículos y cuentas para consultas bulk
        Set<Id> vehicleIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();

        for (VRT_Rental__c rental : rentals) {
            if (rental.VRT_LKP_Vehicle__c != null) {
                vehicleIds.add(rental.VRT_LKP_Vehicle__c);
            }
            if (rental.VRT_LKP_Account__c != null) {
                accountIds.add(rental.VRT_LKP_Account__c);
            }
        }

        // 2. Obtener el tipo de vehículo de cada vehículo implicado
        Map<Id, VRT_Vehicle__c> vehicleMap = new Map<Id, VRT_Vehicle__c>(
            [SELECT Id, VRT_SEL_VehicleType__c
             FROM VRT_Vehicle__c
             WHERE Id IN :vehicleIds]
        );

        // 3. Obtener todas las tarifas activas indexadas por clave "Temporada|TipoVehículo"
        Map<String, VRT_Tarifa__c> tarifaMap = getActiveTarifas();

        // 4. Calcular descuentos de fidelidad
        Map<Id, Boolean> loyaltyMap = calculateLoyaltyDiscount(accountIds);

        // 5. Procesar cada alquiler
        for (VRT_Rental__c rental : rentals) {
            Decimal totalCost = 0;

            // Determinar temporada a partir de la fecha de inicio
            String season = determineSeason(rental.VRT_DAT_InitialDate__c);

            // Obtener tipo de vehículo
            String vehicleType = '';
            if (rental.VRT_LKP_Vehicle__c != null && vehicleMap.containsKey(rental.VRT_LKP_Vehicle__c)) {
                vehicleType = vehicleMap.get(rental.VRT_LKP_Vehicle__c).VRT_SEL_VehicleType__c;
            }

            // Buscar tarifa por clave compuesta (temporada + tipo vehículo, en minúsculas)
            String tarifaKey = (season + '|' + vehicleType).toLowerCase();
            Decimal pricePerDay = 0;

            if (tarifaMap.containsKey(tarifaKey)) {
                pricePerDay = tarifaMap.get(tarifaKey).VRT_DIV_PricePerDay__c;
            }

            // Calcular coste base = precio/día × duración (días)
            Decimal duration = rental.VRT_FOR_Duration__c != null ? rental.VRT_FOR_Duration__c : 0;
            totalCost = pricePerDay * duration;

            // Aplicar descuento de fidelidad si corresponde
            if (rental.VRT_LKP_Account__c != null
                && loyaltyMap.containsKey(rental.VRT_LKP_Account__c)
                && loyaltyMap.get(rental.VRT_LKP_Account__c)) {
                totalCost = totalCost * (1 - LOYALTY_DISCOUNT_PERCENT);
            }

            // Aplicar penalización por devolución tardía si corresponde
            totalCost += calculateLatePenalty(rental, pricePerDay);

            // Asignar coste total al registro (redondeado a 2 decimales)
            rental.VRT_DIV_TotalCost__c = totalCost.setScale(2, RoundingMode.HALF_UP);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Determinar temporada
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Determina la temporada comercial en función del mes de la fecha indicada.
     *          - Alta:  junio, julio, agosto, diciembre (meses 6, 7, 8, 12)
     *          - Media: marzo, abril, mayo, septiembre, octubre (meses 3, 4, 5, 9, 10)
     *          - Baja:  enero, febrero, noviembre (meses 1, 2, 11)
     * @param   startDate Fecha de inicio del alquiler
     * @return  String con el nombre de la temporada ('Alta', 'Media' o 'Baja')
     */
    public static String determineSeason(Date startDate) {
        if (startDate == null) {
            return 'Baja';
        }

        Integer month = startDate.month();

        // Temporada Alta: verano + Navidad
        if (month == 6 || month == 7 || month == 8 || month == 12) {
            return 'Alta';
        }
        // Temporada Media: primavera + principio de otoño
        else if (month == 3 || month == 4 || month == 5 || month == 9 || month == 10) {
            return 'Media';
        }
        // Temporada Baja: invierno
        else {
            return 'Baja';
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Descuento de fidelidad
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Verifica si cada cuenta tiene ≥3 alquileres completados en los
     *          últimos 12 meses. Si los tiene, se le concede un 5% de descuento.
     * @param   accountIds Set de Ids de cuentas a evaluar
     * @return  Map<Id, Boolean> donde la clave es el Account Id y el valor indica
     *          si tiene derecho al descuento de fidelidad (true) o no (false)
     */
    public static Map<Id, Boolean> calculateLoyaltyDiscount(Set<Id> accountIds) {
        Map<Id, Boolean> loyaltyMap = new Map<Id, Boolean>();

        if (accountIds == null || accountIds.isEmpty()) {
            return loyaltyMap;
        }

        // Inicializar todas las cuentas como no elegibles
        for (Id accountId : accountIds) {
            loyaltyMap.put(accountId, false);
        }

        // Fecha límite: 12 meses atrás desde hoy
        Date twelveMonthsAgo = Date.today().addMonths(-12);

        // Contar alquileres completados por cuenta en los últimos 12 meses
        List<AggregateResult> results = [ //AggregateResult es un tipo especial de SObject de Salesforce que devuelve los resultados de queries SOQL con funciones de agregación (COUNT, SUM, AVG, MIN, MAX) y/o GROUP BY 
            SELECT VRT_LKP_Account__c accountId, COUNT(Id) rentalCount // accountId y rentalCount son alias
            FROM VRT_Rental__c
            WHERE VRT_LKP_Account__c IN :accountIds
              AND VRT_SEL_Status__c = 'Completado'
              AND VRT_DAT_InitialDate__c >= :twelveMonthsAgo
            GROUP BY VRT_LKP_Account__c
        ];

        for (AggregateResult ar : results) {
            Id accountId = (Id) ar.get('accountId');
            Integer rentalCount = (Integer) ar.get('rentalCount');

            if (rentalCount >= LOYALTY_MIN_RENTALS) {
                loyaltyMap.put(accountId, true);
            }
        }

        return loyaltyMap;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Penalización por devolución tardía
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Calcula la penalización económica por devolución tardía.
     *          Si la fecha de hoy supera la fecha final planificada (VRT_DAT_FinalDate__c)
     *          y el estado del alquiler sigue 'En curso', se aplica una penalización
     *          del 25% del precio diario por cada día adicional de retraso.
     * @param   rental     Registro del alquiler a evaluar
     * @param   pricePerDay Precio por día de la tarifa aplicable
     * @return  Decimal con el importe de la penalización (0 si no aplica)
     */
    public static Decimal calculateLatePenalty(VRT_Rental__c rental, Decimal pricePerDay) {
        if (rental == null || rental.VRT_DAT_FinalDate__c == null || pricePerDay == null) {
            return 0;
        }

        // Solo penalizar si el alquiler sigue en curso y se ha superado la fecha fin
        if (rental.VRT_SEL_Status__c != 'En curso') {
            return 0;
        }

        Date today = Date.today();
        Integer lateDays = rental.VRT_DAT_FinalDate__c.daysBetween(today);

        if (lateDays <= 0) {
            return 0;
        }

        // Penalización = 25% del precio diario × número de días de retraso
        Decimal penalty = pricePerDay * LATE_PENALTY_PERCENT * lateDays;
        return penalty.setScale(2, RoundingMode.HALF_UP);
    }

    // ──────────────────────────────────────────────────────────────────────
    // Métodos privados auxiliares
    // ──────────────────────────────────────────────────────────────────────

    /**
     * @desc    Obtiene todas las tarifas activas e indexa por clave compuesta
     *          "temporada|tipovehículo" (en minúsculas) para búsqueda O(1).
     * @return  Map<String, VRT_Tarifa__c> con las tarifas activas indexadas
     */
    private static Map<String, VRT_Tarifa__c> getActiveTarifas() {
        Map<String, VRT_Tarifa__c> tarifaMap = new Map<String, VRT_Tarifa__c>();

        List<VRT_Tarifa__c> tarifas = [
            SELECT Id, VRT_SEL_Season__c, VRT_SEL_VehicleType__c, VRT_DIV_PricePerDay__c
            FROM VRT_Tarifa__c
            WHERE VRT_FLG_Active__c = true
        ];

        for (VRT_Tarifa__c tarifa : tarifas) {
            String key = (tarifa.VRT_SEL_Season__c + '|' + tarifa.VRT_SEL_VehicleType__c).toLowerCase();
            tarifaMap.put(key, tarifa);
        }

        return tarifaMap;
    }
}