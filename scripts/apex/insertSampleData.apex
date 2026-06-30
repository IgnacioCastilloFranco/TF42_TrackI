/**
 * Inserta los datos de ejemplo (Account, VRT_Vehicle__c, VRT_Rental__c)
 * a partir de los CSV de la carpeta /data.
 *
 * Ejecutar con:
 *   sf apex run -f scripts/apex/insertSampleData.apex
 */

// -------------------------------------------------------------------------
// 1. Accounts (data/accounts.csv)
// -------------------------------------------------------------------------
List<Account> accounts = new List<Account>{
    new Account(
        Name = 'Tech Solutions Inc',
        AnnualRevenue = 1000000,
        VRT_TXT_Email__c = 'info@techsolutions.com',
        NumberOfEmployees = 50,
        Industry = 'Technology',
        Ownership = 'Public',
        Phone = '555-555-5555',
        Rating = 'Hot',
        Type = 'Prospect',
        VRT_TXT_ExternalId__c = 'ACC0005'
    ),
    new Account(
        Name = 'Global Logistics LLC',
        AnnualRevenue = 500000,
        VRT_TXT_Email__c = 'info@globallogistics.com',
        NumberOfEmployees = 75,
        Industry = 'Transportation',
        Ownership = 'Private',
        Phone = '555-555-5555',
        Rating = 'Warm',
        Type = 'Customer - Direct',
        VRT_TXT_ExternalId__c = 'ACC0004'
    ),
    new Account(
        Name = 'Sunshine Bakery',
        AnnualRevenue = 200000,
        VRT_TXT_Email__c = 'info@sunshinebakery.com',
        NumberOfEmployees = 20,
        Industry = 'Food & Beverage',
        Ownership = 'Public',
        Phone = '555-555-5555',
        Rating = 'Hot',
        Type = 'Customer - Channel',
        VRT_TXT_ExternalId__c = 'ACC0003'
    ),
    new Account(
        Name = 'Green Energy Co',
        AnnualRevenue = 800000,
        VRT_TXT_Email__c = 'info@greenenergyco.com',
        NumberOfEmployees = 100,
        Industry = 'Energy',
        Ownership = 'Subsidiary',
        Phone = '555-555-5555',
        Rating = 'Warm',
        Type = 'Channel Partner / Reseller',
        VRT_TXT_ExternalId__c = 'ACC0002'
    ),
    new Account(
        Name = 'ABC Manufacturing',
        AnnualRevenue = 3000000,
        VRT_TXT_Email__c = 'info@abcmanufacturing.com',
        NumberOfEmployees = 150,
        Industry = 'Manufacturing',
        Ownership = 'Other',
        Phone = '555-555-5555',
        Rating = 'Cold',
        Type = 'Installation Partner',
        VRT_TXT_ExternalId__c = 'ACC0001'
    )
};
upsert accounts VRT_TXT_ExternalId__c;
System.debug('Accounts insertados/actualizados: ' + accounts.size());

// -------------------------------------------------------------------------
// 2. Vehicles (data/vehicles.csv)
// -------------------------------------------------------------------------
List<VRT_Vehicle__c> vehicles = new List<VRT_Vehicle__c>{
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Toyota',    VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Camry',      VRT_DAT_ManufacturedYear__c=Date.newInstance(2018,1,1), VRT_TXT_LicensePlate__c='2234ABC', VRT_TXT_Color__c='Blanco',   VRT_NUM_Mileage__c=35000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=5, VRT_SEL_Condition__c='Recién fabricado',     VRT_NUM_Usage__c=800, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT009'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Honda',     VRT_SEL_VehicleType__c='Moto',  VRT_TXT_Model__c='CRF250L',    VRT_DAT_ManufacturedYear__c=Date.newInstance(2020,1,1), VRT_TXT_LicensePlate__c='9567XYZ', VRT_TXT_Color__c='Rojo',     VRT_NUM_Mileage__c=10000, VRT_SEL_Status__c='En mantenimiento',   VRT_FLG_Available__c=false, VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=1, VRT_SEL_Condition__c='Casi nuevo',            VRT_NUM_Usage__c=50,  VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT010'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Tesla',     VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Model S',    VRT_DAT_ManufacturedYear__c=Date.newInstance(2019,1,1), VRT_TXT_LicensePlate__c='7990DEF', VRT_TXT_Color__c='Azul',     VRT_NUM_Mileage__c=25000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Eléctrico', VRT_NUM_Passengers__c=5, VRT_SEL_Condition__c='Casi nuevo',            VRT_NUM_Usage__c=20,  VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT011'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Yamaha',    VRT_SEL_VehicleType__c='Moto',  VRT_TXT_Model__c='MT-07',      VRT_DAT_ManufacturedYear__c=Date.newInstance(2017,1,1), VRT_TXT_LicensePlate__c='2395GHI', VRT_TXT_Color__c='Negro',    VRT_NUM_Mileage__c=45000, VRT_SEL_Status__c='Fuera de servicio',  VRT_FLG_Available__c=false, VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=2, VRT_SEL_Condition__c='Bastante desgastado',  VRT_NUM_Usage__c=100, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT012'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Hyundai',   VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Accent',     VRT_DAT_ManufacturedYear__c=Date.newInstance(2016,1,1), VRT_TXT_LicensePlate__c='5098KLM', VRT_TXT_Color__c='Gris',     VRT_NUM_Mileage__c=55000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=5, VRT_SEL_Condition__c='Algo desgastado',       VRT_NUM_Usage__c=8,   VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT013'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Toyota',    VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Corolla',    VRT_DAT_ManufacturedYear__c=Date.newInstance(2017,1,1), VRT_TXT_LicensePlate__c='1287ABC', VRT_TXT_Color__c='Rojo',     VRT_NUM_Mileage__c=40000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=5, VRT_SEL_Condition__c='Casi nuevo',            VRT_NUM_Usage__c=200, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT014'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Suzuki',    VRT_SEL_VehicleType__c='Moto',  VRT_TXT_Model__c='V-Strom 650',VRT_DAT_ManufacturedYear__c=Date.newInstance(2019,1,1), VRT_TXT_LicensePlate__c='9856XYZ', VRT_TXT_Color__c='Amarillo', VRT_NUM_Mileage__c=15000, VRT_SEL_Status__c='En mantenimiento',   VRT_FLG_Available__c=false, VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=2, VRT_SEL_Condition__c='Bastante desgastado',  VRT_NUM_Usage__c=300, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT015'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Ford',      VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Fiesta',     VRT_DAT_ManufacturedYear__c=Date.newInstance(2015,1,1), VRT_TXT_LicensePlate__c='7290DEF', VRT_TXT_Color__c='Verde',    VRT_NUM_Mileage__c=60000, VRT_SEL_Status__c='Fuera de servicio',  VRT_FLG_Available__c=false, VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=5, VRT_SEL_Condition__c='Deplorable',            VRT_NUM_Usage__c=500, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT016'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Kawasaki',  VRT_SEL_VehicleType__c='Moto',  VRT_TXT_Model__c='Ninja 300',  VRT_DAT_ManufacturedYear__c=Date.newInstance(2018,1,1), VRT_TXT_LicensePlate__c='2385GHI', VRT_TXT_Color__c='Azul',     VRT_NUM_Mileage__c=25000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=2, VRT_SEL_Condition__c='Recién fabricado',     VRT_NUM_Usage__c=100, VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT017'),
    new VRT_Vehicle__c(VRT_TXT_Brand__c='Chevrolet', VRT_SEL_VehicleType__c='Coche', VRT_TXT_Model__c='Camaro',     VRT_DAT_ManufacturedYear__c=Date.newInstance(2020,1,1), VRT_TXT_LicensePlate__c='5178KLM', VRT_TXT_Color__c='Blanco',   VRT_NUM_Mileage__c=10000, VRT_SEL_Status__c='Listo',              VRT_FLG_Available__c=true,  VRT_SEL_EnergyType__c='Gasolina',  VRT_NUM_Passengers__c=4, VRT_SEL_Condition__c='Casi nuevo',            VRT_NUM_Usage__c=50,  VRT_FLG_NeedsInspection__c=false, VRT_TXT_ExternalId__c='EXT018')
};
upsert vehicles VRT_TXT_ExternalId__c;
System.debug('Vehicles insertados/actualizados: ' + vehicles.size());

// -------------------------------------------------------------------------
// 3. Mapas auxiliares para resolver los lookups por External Id
// -------------------------------------------------------------------------
Map<String, Id> accountIdByExtId = new Map<String, Id>();
for (Account a : accounts) accountIdByExtId.put(a.VRT_TXT_ExternalId__c, a.Id);

Map<String, Id> vehicleIdByExtId = new Map<String, Id>();
for (VRT_Vehicle__c v : vehicles) vehicleIdByExtId.put(v.VRT_TXT_ExternalId__c, v.Id);

// -------------------------------------------------------------------------
// 4. Rentals (data/rentals.csv)
// -------------------------------------------------------------------------
List<VRT_Rental__c> rentals = new List<VRT_Rental__c>{
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0001'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,20), VRT_DIV_TotalCost__c=1700, VRT_SEL_Status__c='Cancelado',  VRT_SEL_PaymentStatus__c='Pendiente', VRT_TXT_Notes__c='Registro de ejemplo Track I #01'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0002'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,26), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Cancelado',  VRT_SEL_PaymentStatus__c='Pendiente', VRT_TXT_Notes__c='Registro de ejemplo Track I #02'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0003'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,14), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Completado', VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #03'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0004'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Completado', VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #04'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0005'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,11), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Completado', VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #05'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0001'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,19), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Completado', VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #06'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0002'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,15), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #07'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0003'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,19), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #08'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0004'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,13), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #09'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0005'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,10), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #10'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0001'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,11), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #11'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0002'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,12), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #12'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0003'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,15), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,22), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='En curso',   VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #13'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0004'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Cancelado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #14'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0005'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Cancelado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #15'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0001'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,15), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #16'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0002'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #17'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0003'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT011'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,17), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1900, VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #18'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0004'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT009'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,15), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1800, VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #19'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0005'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=300,  VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #20'),
    new VRT_Rental__c(VRT_LKP_Account__c=accountIdByExtId.get('ACC0005'), VRT_LKP_Vehicle__c=vehicleIdByExtId.get('EXT013'), VRT_DAT_InitialDate__c=Date.newInstance(2026,1,16), VRT_DAT_FinalDate__c=Date.newInstance(2026,1,18), VRT_DIV_TotalCost__c=1500, VRT_SEL_Status__c='Reservado',  VRT_SEL_PaymentStatus__c='Pagado',    VRT_TXT_Notes__c='Registro de ejemplo Track I #21')
};
insert rentals;
System.debug('Rentals insertados: ' + rentals.size());

System.debug('== Carga de datos de ejemplo completada ==');
