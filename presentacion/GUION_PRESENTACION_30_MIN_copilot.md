# Guion de presentación técnica — AlquilaVehículo S.L.

**Duración preparada:** 30 minutos  
**Formato recomendado:** 25 minutos de exposición y demo + 5 minutos de transición/preguntas.  
**Material:** [PRESENTACION_30_MIN.md](./PRESENTACION_30_MIN.md), una org con datos de ejemplo y el repositorio abierto en VS Code.

## Antes de empezar

1. Tener abierta la app Salesforce y una Account con varios alquileres.
2. Tener una Account con historial suficiente para demostrar fidelidad.
3. Tener un vehículo disponible y otro con una reserva existente.
4. Tener una tarifa activa para el tipo de vehículo y temporada de la demo.
5. Tener preparadas dos parejas de fechas: una solapada y otra contigua.
6. Tener abiertas en VS Code estas clases: `VRT_TRG_Rental`, `VRT_SRV_PricingEngine`, `VRT_SRV_AvailabilityChecker`, `VRT_CTR_RentalConsole` y `VRT_SRV_InvoiceGenerator`.
7. No afirmar una cifra de cobertura sin ejecutar la suite en la org que se vaya a enseñar. El repositorio documenta una cobertura superior al 96%, pero el resultado debe presentarse como evidencia de la ejecución actual.

---

## 1. Apertura — 1 minuto

> Buenos días. Voy a presentar AlquilaVehículo S.L., una solución Salesforce para gestionar el ciclo completo de un alquiler: buscar un vehículo, calcular un precio, validar disponibilidad, aprobar importes elevados y facturar sin bloquear al operador.
>
> La idea central es separar la experiencia de usuario de las reglas de negocio. El LWC hace que el proceso sea rápido, pero el servidor vuelve a validar todo lo importante. Así, una carga masiva, una integración o una edición directa no pueden saltarse las mismas reglas.

**Transición:** “Empiezo por el problema que tuve que resolver, no por la pantalla.”

## 2. Problema de negocio — 2 minutos

> Un alquiler parece una operación sencilla, pero concentra varios riesgos: dos reservas para el mismo vehículo, tarifas inconsistentes, descuentos aplicados de forma manual, aprobaciones que se olvidan y facturas duplicadas.
>
> Además, el equipo operativo necesita respuesta inmediata. No quiere guardar un registro para descubrir después que el precio era incorrecto o que el vehículo no estaba disponible.
>
> Por eso el diseño trata la reserva como un proceso, no como un simple objeto con campos. Hay una entrada interactiva, reglas síncronas para proteger la transacción y trabajo asíncrono para lo que no debe hacer esperar al usuario.

**Punto técnico si preguntan:** “La solución está pensada para que las reglas sean reutilizables desde UI, DML masivo y futuras integraciones.”

## 3. Objetivo y flujo — 2 minutos

> El flujo es: el operador busca la flota, selecciona cuenta y fechas, simula precio y disponibilidad, y solo entonces guarda.
>
> Al guardar, el trigger calcula y valida otra vez. Esto es deliberado: una simulación de UI no es una garantía de integridad porque otro usuario podría haber creado una reserva entre la simulación y el guardado.
>
> Después del guardado se evalúa la aprobación financiera. Cuando corresponde, el proceso queda en manos del flujo declarativo. Y cuando el alquiler debe facturarse, se encola un trabajo que genera la factura, notifica y deja trazabilidad.

## 4. Arquitectura — 2 minutos

> La arquitectura sigue el patrón Trigger–Handler–Service. `VRT_TRG_Rental` solo enruta el contexto. No contiene reglas de precio ni consultas complejas.
>
> `VRT_TRG_RentalHandler` distingue before insert, before update, after insert y after update. En los eventos before se ejecutan precio y disponibilidad, porque todavía puedo modificar el registro o bloquearlo con `addError()`. En los eventos after se lanzan aprobación y facturación, porque ya existe el Id y el registro está persistido.
>
> Los servicios son independientes: pricing, availability, approval e invoice. Esto reduce el acoplamiento y hace que cada regla pueda probarse sin convertir el trigger en el lugar donde vive toda la aplicación.

**Mostrar en VS Code:** primero el trigger y luego el handler; no leer el archivo completo.

## 5. Modelo de datos — 2 minutos

> El modelo separa los conceptos que cambian por razones distintas. Vehicle representa el inventario; Rental representa la operación; Tarifa representa configuración comercial; Factura y LogProceso representan el resultado financiero y la trazabilidad.
>
> La decisión importante es que el precio por día no está codificado como un `if` interminable. Está en `VRT_Tarifa__c`, por tipo y temporada, de forma que un cambio comercial no exige desplegar Apex.
>
> Account aporta el contexto del cliente y permite calcular fidelidad. Rental conserva el resultado calculado, como temporada, precio base, descuento, penalización y total. Esto facilita auditoría: no solo sabemos el total actual, también qué componentes produjeron ese total.
>
> Para una solución productiva revisaría además campos externos únicos, reglas de integridad y permisos de escritura, pero la separación conceptual ya está preparada.

## 6. Motor de precios — 3 minutos

> El punto de entrada es `VRT_SRV_PricingEngine.calculateTotalCost` y recibe una lista de alquileres. Primero recoge Ids de vehículos y cuentas, consulta una vez y crea mapas. Después cada reserva se resuelve en memoria.
>
> La fórmula es tarifa por día por duración. A continuación se aplica el cinco por ciento de fidelidad cuando la cuenta tiene al menos tres alquileres en los últimos doce meses. Finalmente se suma la penalización de devolución tardía, del veinticinco por ciento por día, y se redondea a dos decimales.
>
> Hay dos razones para destacar la lista. Primera, evita una implementación que solo funciona para un registro desde la UI. Segunda, permite procesar cargas de datos y mantiene el consumo de límites bajo control.

**Demo de 90 segundos:**

1. Abrir una tarifa activa y señalar temporada/tipo.
2. En la consola introducir fechas.
3. Mostrar el precio simulado.
4. Cambiar a una cuenta con historial de fidelidad y señalar el cambio.
5. Si la org no tiene datos preparados, explicar la secuencia con la clase y no improvisar cifras.

**Pregunta probable:** “¿Qué ocurre si no existe tarifa?”  
**Respuesta preparada:** “La prueba debe verificar ese escenario como error de negocio. En una revisión de producción también haría que el fallo sea explícito y visible, no un total cero que parezca válido.”

## 7. Disponibilidad — 3 minutos

> La condición de solapamiento es `startA < endB AND endA > startB`. Es estricta: si un alquiler termina el mismo día que empieza el siguiente, se permite continuidad.
>
> En la entrada se agrupa por vehículo, se obtiene el rango global y se realiza una consulta acotada. Luego se indexan los alquileres existentes por vehículo. También se revisan conflictos entre registros del mismo lote, porque no basta con comparar contra lo que ya está en base de datos.
>
> Si hay conflicto en un `before insert` o `before update`, se llama a `addError()` sobre el registro. Salesforce cancela ese registro y el usuario recibe el motivo, en lugar de una excepción genérica.
>
> Esta es una regla que no puede vivir solo en el LWC. La interfaz mejora la experiencia, pero el trigger es la última línea de integridad.

**Demo de 60–90 segundos:**

1. Crear o simular una reserva que cruza una existente.
2. Mostrar el mensaje de conflicto.
3. Cambiar la fecha para que sea contigua.
4. Explicar que el segundo caso debe pasar.

**Pregunta probable:** “¿La implementación intra-lote es O(n²)?”  
**Respuesta preparada:** “Sí, solo dentro del grupo de un vehículo y para el lote entrante. Es una decisión consciente para el tamaño esperado de ese grupo; la consulta contra base de datos está bulkificada. Si el volumen por vehículo creciera mucho, ordenaría intervalos y recorrería una sola vez.”

## 8. Aprobaciones — 2 minutos

> La aprobación está separada entre decisión y configuración. Apex detecta que el importe supera 3.000 o 10.000 euros y envía la reserva. El proceso declarativo decide quién aprueba, bloquea el registro y maneja rechazo.
>
> Esto evita duplicar en Apex un motor de aprobaciones que Salesforce ya proporciona. También permite que el responsable del negocio cambie el aprobador o el comportamiento sin tocar el algoritmo de precios.
>
> En una demo enseñaría un alquiler de importe alto, el estado de aprobación y el bloqueo. La explicación importante es cuándo ocurre: después de persistir, porque la aprobación necesita el registro real.

## 9. Consola LWC — 2 minutos

> `vrtRentalConsole` está pensado para el operador de Account. Muestra alquileres y KPIs, permite crear inline y evita recargas completas.
>
> La parte más interesante es la simulación. Las fórmulas Salesforce no se comportan como campos calculados en un objeto que todavía no se ha guardado. El controlador construye un alquiler temporal, inyecta la duración y llama al mismo motor de precios. No hace DML.
>
> Así se reutiliza la lógica de servidor sin crear registros basura y el usuario recibe una respuesta antes de confirmar.

**Demo:** mostrar KPIs, cambiar fechas, enseñar precio y disponibilidad, y cancelar la modal sin crear el alquiler.

## 10. Buscador de flota — 3 minutos

> `vrtFleetSearch` cubre el caso de búsqueda rápida desde Home. Permite marca, modelo o matrícula y devuelve tarjetas navegables.
>
> Hay dos detalles de UX que también son decisiones técnicas: se esperan al menos dos caracteres y se aplica debounce de 300 milisegundos. Sin debounce, cada pulsación produce una llamada Apex; con él, la búsqueda es más estable y económica.
>
> El controlador limita a 50 resultados, usa una consulta enlazada y `WITH USER_MODE`. El componente transforma los datos en propiedades de presentación: nombre completo, icono, texto de estado y clase visual.

**Demo de 60 segundos:** buscar una marca, borrar hasta un carácter, volver a dos caracteres y abrir el registro.

## 11. Facturación asíncrona — 2 minutos

> La factura no debe hacer que el usuario espere a que termine un proceso de correo y auditoría. Por eso `VRT_SRV_InvoiceGenerator` implementa Queueable.
>
> El trabajo consulta las reservas, comprueba si ya existe una factura, prepara las nuevas y usa `Database.insert` con `allOrNone=false`. De esa forma un fallo individual no revierte todas las facturas del lote. Cada resultado se convierte en un log de éxito o error. Si hay email, se prepara el mensaje y también se refleja su resultado.
>
> El coste de esta decisión es la eventualidad: justo después de guardar, la factura puede no existir todavía. La compensación es una experiencia rápida y un log consultable. En producción añadiría monitorización del AsyncApexJob y una estrategia explícita de reintento.

## 12. Seguridad y calidad — 2 minutos

> `with sharing` protege la visibilidad de registros, pero no resuelve por sí solo CRUD y FLS. Los controladores expuestos a LWC usan `WITH USER_MODE` para que la consulta respete el contexto del usuario.
>
> En calidad, la estructura evita SOQL y DML dentro de bucles de negocio. Se usan Sets para recopilar Ids, Maps para relacionar datos y listas para DML agrupado.
>
> La suite debe cubrir no solo el camino feliz: ausencia de tarifa, solapamiento, fechas contiguas, actualización conflictiva, carga masiva, factura duplicada y errores parciales. Eso es especialmente importante en Salesforce porque los límites de gobernador hacen que una implementación que funciona con un registro falle con 200.

## 13. Pruebas y despliegue — 2 minutos

> El proyecto se despliega como Salesforce DX. La secuencia es desplegar metadata, cargar datos de ejemplo, ejecutar pruebas con cobertura y abrir la org.
>
> No presentaría la cobertura como un número decorativo. Ejecutaría la suite en la org que estoy mostrando y enseñaría el resultado. El repositorio incluye clases de test por servicio, una fábrica de datos y documentación que recoge cobertura superior al umbral del reto.
>
> También distinguiría tests Apex de tests LWC: Apex comprueba reglas y persistencia; Jest debe comprobar el comportamiento del componente, como debounce, estados vacíos, navegación y tratamiento de errores.

## 14. Cierre — 2 minutos

> La solución demuestra una evolución completa en la plataforma: modelo de datos, Apex modular, experiencia LWC, configuración declarativa, asincronía, seguridad y pruebas.
>
> Las reglas críticas están en servidor; la UI aporta velocidad, no autoridad. Los procesos pesados están desacoplados; los resultados se auditan. Y las tarifas y aprobaciones quedan configurables donde corresponde.
>
> Si tuviera una siguiente iteración, priorizaría idempotencia reforzada con un identificador externo único, monitorización operativa de los jobs y una estrategia de concurrencia para dos usuarios que intenten reservar el mismo vehículo al mismo tiempo.
>
> Ese es el criterio que he seguido: no solo hacer que el caso de demo funcione, sino dejar una base mantenible y segura para que el proceso pueda crecer.

---

## Preguntas técnicas probables

### ¿Por qué no poner todo en Flow?

> Flow sería válido para automatizaciones declarativas sencillas. Elegí Apex para las reglas algorítmicas y bulkificadas de precios, intervalos de fechas y tolerancia a fallos parciales. La aprobación sí aprovecha el mecanismo declarativo porque es configuración de negocio.

### ¿Por qué validar dos veces, en LWC y trigger?

> La primera validación es UX y evita frustración. La segunda es integridad: entre la simulación y el guardado puede cambiar el estado de la flota, y también puede entrar una integración o una carga masiva.

### ¿Cómo controlarías dos reservas simultáneas?

> El trigger reduce el riesgo pero la concurrencia real requiere una decisión de producto y técnica: locking/serialización por vehículo, un mecanismo de reserva temporal o un objeto de disponibilidad por intervalo con control de unicidad. Lo documentaría como una evolución explícita, no asumiría que una consulta aislada elimina todas las carreras.

### ¿Qué diferencia hay entre `with sharing` y `WITH USER_MODE`?

> `with sharing` aplica reglas de compartición de registros. `WITH USER_MODE` hace que la consulta respete también permisos de objeto y campo. Son capas distintas y ambas son relevantes en un controlador LWC.

### ¿Qué harías si falla el email?

> La factura ya puede haber sido creada, así que no intentaría revertirla automáticamente. Registrar el fallo, exponer el estado y permitir reintento controlado es más seguro. La operación debe ser idempotente para no crear una segunda factura.

### ¿Qué mejorarías antes de producción?

> Validaría todos los permisos de escritura, endurecería idempotencia con un External ID único, monitorizaría Queueable/Platform limits, añadiría pruebas de concurrencia y confirmaría con negocio las reglas exactas de temporada y penalización.
