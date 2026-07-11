# Documento Técnico de Decisiones de Arquitectura – AlquilaVehículo (Track II)

Este documento resume las principales decisiones técnicas y de arquitectura adoptadas durante la evolución de la aplicación AlquilaVehículo, justificando su diseño bajo estándares de robustez, seguridad y escalabilidad en Salesforce Platform.

---

## 1. Patrón de Diseño del Trigger (Separación de Responsabilidades)

* **Decisión**: Centralización de la automatización en un único trigger por objeto (`VRT_TRG_Rental`), delegando en un gestor de contexto (`VRT_TRG_RentalHandler`) y abstrayendo la lógica funcional en servicios independientes (`VRT_SRV_PricingEngine`, `VRT_SRV_AvailabilityChecker`, `VRT_SRV_ApprovalManager`, `VRT_SRV_InvoiceGenerator`).
* **Justificación**: Evita el desorden de múltiples triggers operando de manera simultánea en el mismo objeto (lo cual introduce indeterminismo en el orden de ejecución). Cumple con las guías oficiales de Salesforce para separación de responsabilidades, garantizando un código modular y fácil de mantener.

---

## 2. Simulación de Precios Dinámicos en Memoria (LWC)

* **Decisión**: Inyección dinámica en memoria de campos de fórmula (como `VRT_FOR_Duration__c`) mediante serialización/deserialización JSON en `VRT_CTR_RentalConsole.simulateAndValidateRental`, previo a invocar el motor de precios `VRT_SRV_PricingEngine`.
* **Justificación**: En Salesforce, los campos de tipo Fórmula no se calculan en base de datos hasta que el registro es insertado/actualizado mediante DML. Para permitir que el LWC ofrezca una simulación en tiempo real y reactiva del coste total sin forzar una inserción DML real (o recarga de página), se simuló el valor de duración del alquiler en memoria inyectándolo directamente en el objeto no guardado.

---

## 3. Desacoplamiento de Validaciones de Solapamiento

* **Decisión**: Separación del chequeo de disponibilidad en dos vías:
  1. Validaciones directas DML en el trigger vía `VRT_SRV_AvailabilityChecker` (añadiendo errores a nivel de registro con `.addError()`).
  2. Consulta de base de datos directa en el controlador LWC para la validación previa del modal de creación.
* **Justificación**: Invocar `.addError()` sobre registros que no están dentro de un contexto de trigger DML nativo genera la excepción fatal de sistema `SObject row does not allow errors`. El LWC consulta la disponibilidad en vivo de manera segura y desacoplada mediante un filtro de solapamiento SOQL.

---

## 4. Procesamiento Asíncrono de Facturación (Queueable Apex)

* **Decisión**: Generación automática de facturas, envío de correos de cortesía y registro de logs encapsulados en un trabajo encolable asíncrono (`VRT_SRV_InvoiceGenerator` implementando `Queueable`).
* **Justificación**: La creación de facturas e inserción de logs, combinada con el envío de emails (`Messaging.sendEmail`), son operaciones con alta demanda de recursos (CPU limit y límites de correo). Al encolarlas asíncronamente, se desvinculan del hilo de ejecución síncrono del trigger del usuario, evitando bloqueos de pantalla y garantizando una experiencia de usuario rápida y fluida.

---

## 5. Diseño Bulk-Safe y Tolerancia a Fallos Asíncronos

* **Decisión**: Uso de métodos del sistema `Database.insert(records, false)` para inserciones masivas de facturas y logs.
* **Justificación**: Al procesar alquileres de forma masiva, un solo error de DML en una factura no debe detener ni revertir el lote completo de inserciones exitosas. Inspeccionando los objetos `Database.SaveResult`, el sistema registra logs individuales con el estado `Éxito` o `Error` de forma asilada y precisa.

---

## 6. Seguridad Declarativa (FLS y CRUD)

* **Decisión**: Exposición de controladores Apex anotados con `@AuraEnabled` utilizando la cláusula `WITH USER_MODE`.
* **Justificación**: A diferencia de `with sharing` (que solo valida la visibilidad de registros), `WITH USER_MODE` instruye de manera nativa al motor de base de datos de Salesforce a validar los permisos de acceso al objeto y a cada campo individual del usuario actual. Esto previene de forma contundente la escalada de privilegios y fugas de datos sensibles a través de componentes LWC.
