# Cumplimiento de Requisitos Globales de Arquitectura y Calidad

Este documento detalla cómo la evolución técnica realizada en el proyecto cumple estrictamente con los estándares y requerimientos globales exigidos.

---

## 1. Separación de Responsabilidades (Trigger → Handler → Service)

El flujo de ejecución de la lógica de negocio se divide en capas especializadas:

- **Trigger (`VRT_TRG_Rental`)**: Es el punto de entrada y no contiene lógica. Delega inmediatamente todos los eventos a la clase Handler.
- **Handler (`VRT_TRG_RentalHandler`)**: Centraliza la lógica de enrutamiento de contextos (`Before Insert`, `Before Update`, `After Insert`, `After Update`).
- **Clases Service / Helper**:
  - `VRT_SRV_PricingEngine`: Encapsula toda la lógica de negocio del motor de tarifas dinámicas, temporadas y recargos.
  - `VRT_SRV_AvailabilityChecker`: Valida conflictos de solapamiento de fechas.
  - `VRT_SRV_ApprovalManager`: Gestiona de forma aislada el circuito de aprobaciones financieras.
  - `VRT_SRV_InvoiceGenerator`: Genera facturas, gestiona emails y logs de auditoría en background.

---

## 2. Bulkification Obligatoria

Toda la lógica de Apex está diseñada para procesar colecciones masivas de registros de manera eficiente:

- **Listas y Mapas**: Los métodos de cálculo de precios y validaciones aceptan listas (`List<VRT_Rental__c>`) y mapas para operar en lote.
- **Mapas de Relación**: `VRT_SRV_AvailabilityChecker` mapea matrículas y rangos de fechas consolidados para resolver solapamientos de cientos de registros en una única transacción de forma masiva y robusta.

---

## 3. No SOQL/DML en Bucles (Loops)

Se prohíbe explícitamente realizar consultas a base de datos o DML dentro de estructuras repetitivas (`for`, `while`):

- **Consolidación de Datos**: Las consultas SOQL se realizan al inicio de los métodos utilizando conjuntos de IDs acumulados previamente.
- **Operaciones DML Agrupadas**: Los registros a insertar o actualizar se añaden a colecciones en memoria (`List<SObject>`) y se ejecuta una única sentencia DML al final del método (ej. `insert invoicesToInsert;` o `update vehicles;`).

---

## 4. Manejo Correcto de Excepciones

- **Manejo Seguro en Trigger**: En `VRT_SRV_AvailabilityChecker`, se utiliza `.addError()` para adjuntar errores directamente en los registros afectados en el contexto del trigger, evitando excepciones no controladas de sistema.
- **Operaciones asíncronas seguras**: En `VRT_SRV_InvoiceGenerator`, se utiliza `Database.insert(invoicesToInsert, false)` (éxito parcial). Esto permite capturar errores de forma individual mediante la inspección de `Database.SaveResult[]`, registrando los detalles de cualquier fallo DML en un objeto de logs (`VRT_LogProceso__c`) sin detener el procesamiento de los registros correctos.

---

## 5. Uso Adecuado de Asincronía

- **Queueable Apex**: Se ha implementado `VRT_SRV_InvoiceGenerator` como una clase asíncrona Queueable para gestionar la facturación y notificaciones por correo electrónico al completar un alquiler.
- **Ventajas**: Esto evita demorar la transacción principal DML en la interfaz de usuario, previniendo timeouts y aumentando los límites de gobernador disponibles para la inserción y envío de correos.

---

## 6. Seguridad: Respetar CRUD y FLS (Field-Level Security)

- **System Mode vs. User Mode**: Por defecto, el código Apex se ejecuta en *System Mode* (ignora los permisos CRUD y FLS del perfil del usuario). Aunque se utilice `with sharing` para respetar las reglas de compartición de registros, esto no restringe el acceso a nivel de objeto o campos.
- **Implementación de `WITH USER_MODE`**: Las consultas SOQL ejecutadas desde los controladores Apex expuestos a los componentes LWC (`VRT_CTR_FleetSearch` y `VRT_CTR_RentalConsole`) emplean explícitamente la cláusula `WITH USER_MODE`.
- **Validación Automática de CRUD/FLS**: Al añadir `WITH USER_MODE`, el motor de base de datos de Salesforce valida nativamente:
  1. Si el perfil o Permission Set del usuario tiene permisos de **Lectura** en el objeto custom (CRUD, ej: `VRT_Vehicle__c`).
  2. Si el usuario tiene acceso de **Lectura** para cada campo individual listado en el `SELECT` (FLS, ej: `VRT_TXT_Brand__c`, `VRT_TXT_Model__c`).
- **Mitigación de Riesgos**: En caso de que un usuario intente acceder de forma malintencionada o mediante payloads modificados a campos no permitidos, la consulta fallará inmediatamente arrojando un error de sistema (`QueryException`), evitando fugas de información y cumpliendo con las directrices más estrictas de seguridad (como las revisiones PMD y el AppExchange Security Review).

---

## 7. Cobertura de Test Mínima (Excede el 85%)

El total de cobertura de código tras ejecutar todos los tests es del **96%** (muy por encima del umbral mínimo del 85%):

- `VRT_TRG_RentalHandler` & Helper: **100%**
- `VRT_SRV_PricingEngine`: **100%**
- `VRT_SRV_AvailabilityChecker`: **96%**
- `VRT_SRV_ApprovalManager`: **90%**
- `VRT_CTR_RentalConsole` (LWC Controller): **97%**
- `VRT_SRV_InvoiceGenerator` (Queueable): **91%**
- `VRT_CTR_FleetSearch` (LWC Controller): **100%**

---

## 8. Tests con Escenarios Negativos y Masivos

- **Escenarios Masivos (Bulk)**:
  - `VRT_SRV_PricingEngine_Test.calculateTotalCost_bulk_200registros` inserta 200 vehículos y 200 alquileres simultáneamente para validar que el motor calcula los importes bulkificados sin fallar por governor limits.
  - `VRT_SRV_AvailabilityChecker_Test.validateAvailability_bulk_ok` prueba inserción bulk de alquileres sin conflicto.
- **Escenarios Negativos**:
  - Tests que validan fallos al no existir tarifas vigentes.
  - Tests que validan que se arrojan errores claros al intentar registrar fechas solapadas o consecutivas inválidas.
  - Tests que validan el registro de logs tipo `Error` si falla la inserción de facturas mediante desbordes numéricos provocados de forma segura.

---

## 9. Uso de Salesforce DX para Despliegue

El proyecto se estructura bajo el estándar de Salesforce DX:
- Dispone del archivo `sfdx-project.json` en la raíz del espacio de trabajo.
- Control de exclusiones mediante el archivo `.forceignore`.
- Los componentes y clases se encuentran estructurados en directorios estándar (`force-app/main/default/classes`, `lwc`, `flexipages`, `tabs`, `objects`).
- Los despliegues y pruebas se orquestan mediante la CLI unificada `sf` (ej. `sf project deploy start` y `sf apex run test`).
