# Track II - AlquilaVehículo S.L. - Plan de Implementación

## Contexto

Evolución del proyecto Salesforce de AlquilaVehículo S.L. (Track II). El proyecto actual tiene objetos `VRT_Rental__c` y `VRT_Vehicle__c` con triggers básicos (after insert/update). Se debe ampliar con pricing dinámico, control de disponibilidad, aprobaciones financieras, LWC, facturación async y buscador de flota.

### Estado Actual del Código
- **Objetos existentes**: `VRT_Rental__c`, `VRT_Vehicle__c`, `Account`, `Contact`
- **Trigger existente**: `VRT_TRG_Rental` (after insert, after update) → `VRT_TRG_RentalHandler` → `VRT_TRG_RentalHandlerHelper`
- **Patrón**: Trigger → Handler → Helper (lo evolucionamos a Trigger → Handler → Service)
- **API Version**: 66.0
- **Campos Rental**: Status, PaymentStatus, TotalCost (Currency), InitialDate, FinalDate, Duration (formula), Account (Lookup), Vehicle (Lookup), Notes
- **Campos Vehicle**: Brand, Model, LicensePlate, VehicleType (Coche/Moto), Condition, EnergyType, Status, Available, Mileage, Usage, Passengers, ManufacturedYear, Color, ExternalId, NeedsInspection

---

## User Review Required

> [!IMPORTANT]
> **Paso 0: Crear una nueva Salesforce Org (Developer Edition -Más simple, gratuita, sin tiempo límite)**
> Antes de comenzar el desarrollo, necesitas una org de Salesforce conectada.

> [!IMPORTANT]
> **Nuevo objeto `VRT_Tarifa__c` (Pricing Rate)**: Se creará un Custom Object nuevo para almacenar las tarifas administrables (precio por día según tipo de vehículo y temporada).

> [!IMPORTANT]
> **Nuevo objeto `VRT_Factura__c` (Invoice)**: Se necesita un nuevo objeto para la facturación automática.

---

## Paso 0: Creación de la Salesforce Org

```bash
# 1. Registrarse en https://developer.salesforce.com/signup
# 2. Autenticarse
sf org login web --alias RetoNTT --set-default

# 3. Desplegar los metadatos del Track II
sf project deploy start --source-dir force-app

# 4. Abrir la org
sf org open
```

---

## Proposed Changes

El proyecto se divide en **6 fases** que se implementarán en orden. Cada fase corresponde a un requerimiento funcional.

---

### Fase 1: Sistema de Precios Dinámicos (Pricing Engine)

#### [NEW] Objeto Custom: `VRT_Tarifa__c` (Pricing Rate)
Nuevo objeto para almacenar las tarifas administrables con los campos:
| Campo | API Name | Tipo | Descripción |
|-------|----------|------|-------------|
| Tipo Vehículo | `VRT_SEL_VehicleType__c` | Picklist (Coche/Moto) | Tipo de vehículo al que aplica |
| Temporada | `VRT_SEL_Season__c` | Picklist (Alta/Media/Baja) | Temporada |
| Precio por Día | `VRT_DIV_PricePerDay__c` | Currency | Precio base por día |
| Activa | `VRT_FLG_Active__c` | Checkbox | Si la tarifa está activa |

**Directorio**: `force-app/main/default/objects/VRT_Tarifa__c/`

#### [NEW] [VRT_SRV_PricingEngine.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_PricingEngine.cls)
Clase Service con la lógica de cálculo de precios:
- `calculateTotalCost(List<VRT_Rental__c> rentals)`: Método principal bulk
- `determineSeason(Date startDate)`: Determina temporada (Alta/Media/Baja) según el mes
- `calculateLoyaltyDiscount(Set<Id> accountIds)`: Verifica si el cliente tiene ≥3 alquileres en últimos 12 meses → 5% descuento
- `calculateLatePenalty(...)`: Penalización 25% por día adicional si devolución tardía

**Reglas de temporada**:
- **Alta**: Enero, Abril, Julio, Agosto, Diciembre
- **Media**: Febrero, Mayo, Junio, Septiembre
- **Baja**: Marzo, Octubre, Noviembre

#### [NEW] Campos adicionales en `VRT_Rental__c`
| Campo | API Name | Tipo | Descripción |
|-------|----------|------|-------------|
| Temporada | `VRT_SEL_Season__c` | Picklist | Temporada calculada automáticamente |
| Descuento Fidelidad | `VRT_CHK_LoyaltyDiscount__c` | Checkbox | Si se aplicó descuento por fidelidad |
| Precio Base por Día | `VRT_DIV_BasePricePerDay__c` | Currency | Precio base antes de descuentos |
| Fecha Devolución Real | `VRT_DAT_ActualReturnDate__c` | Date | Fecha real de devolución (para penalización) |
| Penalización | `VRT_DIV_Penalty__c` | Currency | Monto de penalización por retraso |

#### [MODIFY] [VRT_TRG_Rental.trigger](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/triggers/VRT_TRG_Rental.trigger)
- Agregar contexto **before insert** y **before update** para cálculo de precios y validación de disponibilidad

#### [MODIFY] [VRT_TRG_RentalHandler.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_TRG_RentalHandler.cls)
- Agregar métodos `onBeforeInsert()` y `onBeforeUpdate()`
- Delegar lógica al nuevo service `VRT_SRV_PricingEngine`

#### [NEW] [VRT_SRV_PricingEngine_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_PricingEngine_Test.cls)
Tests del motor de precios:
- Test cálculo básico por tipo y temporada
- Test descuento fidelidad (≥3 alquileres últimos 12 meses)
- Test penalización por retraso
- Test error cuando no existe tarifa válida
- Test masivo (bulk) con 200+ registros
- Test escenario negativo: sin tarifa → bloqueo

---

### Fase 2: Control de Disponibilidad de Flota

#### [NEW] [VRT_SRV_AvailabilityChecker.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_AvailabilityChecker.cls)
Clase Service para validar solapamientos:
- `validateAvailability(List<VRT_Rental__c> rentals)`: Valida que no exista solapamiento
- Regla de solapamiento: `startA < endB AND endA > startB`
- Permite que un alquiler termine el mismo día que otro empieza (`startA < endB AND endA > startB`, usando `<` estricto en lugar de `<=`)
- Bulk-safe: agrupa consultas por vehículo
- Se invoca en **before insert** y **before update**

#### [NEW] [VRT_SRV_AvailabilityChecker_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_AvailabilityChecker_Test.cls)
- Test sin solapamiento → OK
- Test con solapamiento → error
- Test caso límite: mismo día fin/inicio → OK
- Test masivo
- Test actualización de fechas que genera conflicto

---

### Fase 3: Sistema de Aprobaciones Financieras

#### [NEW] Approval Process (Metadata XML)
Proceso de aprobación declarativo configurado con metadata:
- **Nivel 1** (>3.000€): Aprobación del Gerente
- **Nivel 2** (>10.000€): Doble aprobación (Gerente + Responsable Financiero)
- Record Lock durante aprobación
- En caso de rechazo → Estado = "Cancelado" + motivo registrado

**Archivos**:
- `force-app/main/default/approvalProcesses/VRT_Rental__c.VRT_APR_FinancialApproval.approvalProcess-meta.xml`

#### [NEW] [VRT_SRV_ApprovalManager.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_ApprovalManager.cls)
- `submitForApproval(List<VRT_Rental__c> rentals)`: Envía automáticamente a aprobación si Coste Total > 3.000€
- Se invoca en after insert/after update cuando el coste total cambia

#### [NEW] [VRT_SRV_ApprovalManager_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_ApprovalManager_Test.cls)

---

### Fase 4: Consola Operativa (Lightning Web Component)

#### [NEW] LWC: `vrtRentalConsole`
Componente Lightning embebido en la página de Account:

**Archivos**:
- `force-app/main/default/lwc/vrtRentalConsole/vrtRentalConsole.html`
- `force-app/main/default/lwc/vrtRentalConsole/vrtRentalConsole.js`
- `force-app/main/default/lwc/vrtRentalConsole/vrtRentalConsole.css`
- `force-app/main/default/lwc/vrtRentalConsole/vrtRentalConsole.js-meta.xml`

**Funcionalidades**:
- Tabla de alquileres activos del Account con filtrado y ordenación
- Formulario de creación de alquiler inline
- Simulación de precio antes de guardar (llama al PricingEngine via Apex)
- Mensajes de error en tiempo real (toast + inline)
- Sin recargas completas de página

#### [NEW] [VRT_CTR_RentalConsole.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_CTR_RentalConsole.cls)
Apex Controller para el LWC:
- `@AuraEnabled getActiveRentals(Id accountId)`: Obtiene alquileres activos
- `@AuraEnabled simulatePrice(...)`: Simula precio sin guardar
- `@AuraEnabled createRental(...)`: Crea nuevo alquiler
- `@AuraEnabled getAvailableVehicles()`: Lista vehículos disponibles

#### [NEW] [VRT_CTR_RentalConsole_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_CTR_RentalConsole_Test.cls)

#### [MODIFY] FlexiPage de Account
Se añadirá el componente `vrtRentalConsole` a la página de Account.

---

### Fase 5: Facturación Automática (Async Processing)

#### [NEW] Objeto Custom: `VRT_Factura__c` (Invoice)
| Campo | API Name | Tipo | Descripción |
|-------|----------|------|-------------|
| Alquiler | `VRT_LKP_Rental__c` | Lookup(VRT_Rental__c) | Alquiler asociado |
| Cliente | `VRT_LKP_Account__c` | Lookup(Account) | Cliente |
| Importe | `VRT_DIV_Amount__c` | Currency | Importe de la factura |
| Fecha Emisión | `VRT_DAT_IssueDate__c` | Date | Fecha de emisión |
| Estado | `VRT_SEL_Status__c` | Picklist | Emitida / Enviada / Error |
| Número Factura | Name | AutoNumber | Número auto-generado |

#### [NEW] Objeto Custom: `VRT_LogProceso__c` (Process Log)
| Campo | API Name | Tipo | Descripción |
|-------|----------|------|-------------|
| Tipo Proceso | `VRT_TXT_ProcessType__c` | Text | Tipo de proceso (Facturación, etc.) |
| Registro Relacionado | `VRT_TXT_RelatedRecordId__c` | Text | Id del registro procesado |
| Estado | `VRT_SEL_Status__c` | Picklist | Éxito / Error |
| Mensaje | `VRT_TXL_Message__c` | Long Text Area | Detalle del resultado |
| Fecha Ejecución | `VRT_DAT_ExecutionDate__c` | DateTime | Timestamp de ejecución |

#### [NEW] [VRT_SRV_InvoiceGenerator.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_InvoiceGenerator.cls)
Implementa `Queueable` para procesamiento asíncrono:
- Genera factura cuando alquiler cambia a "Completado"
- Envía notificación por email al cliente
- Registra log del proceso
- Previene duplicados (verifica si ya existe factura para ese alquiler)
- Maneja errores y los registra

#### [NEW] [VRT_SRV_InvoiceGenerator_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_SRV_InvoiceGenerator_Test.cls)

---

### Fase 6: Buscador Global de Flota

#### [NEW] LWC: `vrtFleetSearch`
Componente de búsqueda en la Home Page:
- Búsqueda por matrícula, marca o modelo
- Tolerante a texto parcial (LIKE '%term%')
- Resultados estructurados con link al detalle del vehículo
- Respuesta rápida

**Archivos**:
- `force-app/main/default/lwc/vrtFleetSearch/vrtFleetSearch.html`
- `force-app/main/default/lwc/vrtFleetSearch/vrtFleetSearch.js`
- `force-app/main/default/lwc/vrtFleetSearch/vrtFleetSearch.css`
- `force-app/main/default/lwc/vrtFleetSearch/vrtFleetSearch.js-meta.xml`

#### [NEW] [VRT_CTR_FleetSearch.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_CTR_FleetSearch.cls)
- `@AuraEnabled searchVehicles(String searchTerm)`: Busca usando SOSL o SOQL LIKE
- Respeta CRUD/FLS con `WITH SECURITY_ENFORCED`

#### [NEW] [VRT_CTR_FleetSearch_Test.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_CTR_FleetSearch_Test.cls)

---

### Fase 7: Testing y Calidad

#### [NEW] [VRT_TestDataFactory.cls](file:///c:/Users/Nacho/Desktop/Salesforce/TF42_TrackI/force-app/main/default/classes/VRT_TestDataFactory.cls)
Factoría centralizada de datos de test:
- `createAccount()`, `createVehicle()`, `createRental()`, `createTarifa()`
- Métodos para escenarios bulk (200+ registros)

**Meta de cobertura**: ≥85% en todas las clases

---

## Resumen de Archivos por Componente

| Fase | Archivos Nuevos | Archivos Modificados |
|------|----------------|---------------------|
| 1. Pricing Engine | 6 clases + 1 objeto + 5 campos | Trigger + Handler |
| 2. Disponibilidad | 2 clases | Handler (ya modificado) |
| 3. Aprobaciones | 2 clases + 1 approval process | - |
| 4. Consola LWC | 1 LWC (4 files) + 2 clases | FlexiPage Account |
| 5. Facturación | 2 clases + 2 objetos | Handler (after update) |
| 6. Buscador | 1 LWC (4 files) + 2 clases | - |
| 7. Testing | 1 clase (TestDataFactory) | - |

---

## Verification Plan

### Automated Tests
```bash
# Ejecutar todos los tests
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10

# Verificar cobertura ≥ 85%
sf apex get test --test-run-id <runId> --code-coverage
```

### Manual Verification
1. Crear un alquiler → verificar cálculo automático de precio
2. Intentar crear alquiler sin tarifa → verificar bloqueo
3. Crear alquiler con solapamiento → verificar error
4. Crear alquiler > 3.000€ → verificar que se lanza aprobación
5. Completar alquiler → verificar factura generada async
6. Probar buscador de flota con texto parcial
7. Verificar consola operativa en la página del Account
8. Ejecutar test bulk con Data Loader (200+ registros)

### Deployment Validation
```bash
# Validar despliegue (dry-run)
sf project deploy start --source-dir force-app --dry-run --test-level RunLocalTests

# Despliegue final
sf project deploy start --source-dir force-app --test-level RunLocalTests
```
