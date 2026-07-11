/**
 * @author      ICASTILLOF
 * @since       11/07/2026
 * @desc        TestDataFactory centralizado para la generación de registros
 *              de prueba reutilizables en los tests unitarios.
 *              Declarada como @IsTest para excluirla de los límites de tamaño.
 *
 * @history     11/07/2026 - ICASTILLOF - Creación de la clase
 */
@IsTest
public class VRT_TestDataFactory {

    private static Integer licenseCounter = 0;

    /**
     * @desc    Genera una Cuenta de prueba (sin insertar)
     */
    public static Account createAccount(String name, String email) {
        return new Account(
            Name = name,
            VRT_TXT_Email__c = email
        );
    }

    /**
     * @desc    Inserta una Cuenta de prueba
     */
    public static Account insertAccount(String name, String email) {
        Account acc = createAccount(name, email);
        insert acc;
        return acc;
    }

    /**
     * @desc    Genera un Vehículo de prueba (sin insertar)
     */
    public static VRT_Vehicle__c createVehicle(String brand, String model, String type) {
        licenseCounter++;
        String plate = type.equalsIgnoreCase('Moto') ? 'M' : 'C';
        plate += String.valueOf(licenseCounter).leftPad(6, '0');

        return new VRT_Vehicle__c(
            VRT_TXT_Brand__c        = brand,
            VRT_TXT_Model__c        = model,
            VRT_SEL_VehicleType__c  = type,
            VRT_FLG_Available__c    = true,
            VRT_SEL_Status__c       = 'Listo',
            VRT_NUM_Mileage__c      = 1000,
            VRT_NUM_Usage__c        = 0,
            VRT_TXT_LicensePlate__c = plate.left(7),
            VRT_NUM_Passengers__c   = type.equalsIgnoreCase('Moto') ? 2 : 5,
            VRT_SEL_EnergyType__c   = 'Gasolina'
        );
    }

    /**
     * @desc    Inserta un Vehículo de prueba
     */
    public static VRT_Vehicle__c insertVehicle(String brand, String model, String type) {
        VRT_Vehicle__c vehicle = createVehicle(brand, model, type);
        insert vehicle;
        return vehicle;
    }

    /**
     * @desc    Genera una Tarifa de prueba (sin insertar)
     */
    public static VRT_Tarifa__c createTarifa(String season, String vehicleType, Decimal pricePerDay) {
        return new VRT_Tarifa__c(
            VRT_SEL_Season__c      = season,
            VRT_SEL_VehicleType__c = vehicleType,
            VRT_DIV_PricePerDay__c = pricePerDay,
            VRT_FLG_Active__c      = true
        );
    }

    /**
     * @desc    Inserta una Tarifa de prueba
     */
    public static VRT_Tarifa__c insertTarifa(String season, String vehicleType, Decimal pricePerDay) {
        VRT_Tarifa__c tarifa = createTarifa(season, vehicleType, pricePerDay);
        insert tarifa;
        return tarifa;
    }

    /**
     * @desc    Genera un Alquiler de prueba (sin insertar)
     */
    public static VRT_Rental__c createRental(Id vehicleId, Id accountId, Date startDate, Date endDate) {
        return new VRT_Rental__c(
            VRT_LKP_Vehicle__c       = vehicleId,
            VRT_LKP_Account__c       = accountId,
            VRT_DAT_InitialDate__c   = startDate,
            VRT_DAT_FinalDate__c     = endDate,
            VRT_SEL_Status__c        = 'Reservado',
            VRT_SEL_PaymentStatus__c = 'Pendiente'
        );
    }

    /**
     * @desc    Inserta un Alquiler de prueba
     */
    public static VRT_Rental__c insertRental(Id vehicleId, Id accountId, Date startDate, Date endDate) {
        VRT_Rental__c rental = createRental(vehicleId, accountId, startDate, endDate);
        insert rental;
        return rental;
    }

    /**
     * @desc    Inserta una Factura de prueba
     */
    public static VRT_Factura__c insertFactura(Id rentalId, Decimal amount) {
        VRT_Factura__c fact = new VRT_Factura__c(
            VRT_LKP_Rental__c      = rentalId,
            VRT_DIV_Amount__c      = amount,
            VRT_DAT_InvoiceDate__c = Date.today()
        );
        insert fact;
        return fact;
    }

    /**
     * @desc    Inserta un Log de Proceso de prueba
     */
    public static VRT_LogProceso__c insertLogProceso(String processName, String status, String message, Id rentalId) {
        VRT_LogProceso__c log = new VRT_LogProceso__c(
            VRT_TXT_ProcessName__c = processName,
            VRT_SEL_Status__c      = status,
            VRT_TXT_Message__c     = message,
            VRT_LKP_Rental__c      = rentalId
        );
        insert log;
        return log;
    }
}
