---
marp: true
theme: default
paginate: true
title: "AlquilaVehículo S.L. - solución Salesforce"
description: "Presentación técnica de 30 minutos"
---

# AlquilaVehículo S.L.
## De una reserva a una operación completa en Salesforce

**Solución técnica para el reto NTT**  
Autor: Ignacio Castillo  
Duración: 30 minutos + preguntas

<!--
TIEMPO: 1 min
MENSAJE: No voy a enseñar solo pantallas: voy a explicar cómo una operación de alquiler atraviesa el modelo, la lógica, la seguridad y la automatización.
-->

---

# 1. El problema de negocio

Una empresa de alquiler necesita controlar, en un mismo proceso:

- Flota y disponibilidad real.
- Precio según vehículo, temporada y cliente.
- Reservas sin solapamientos.
- Aprobaciones para importes elevados.
- Facturación y notificación al cliente.
- Una experiencia rápida para el equipo operativo de nuestro cliente que gestiona reservas y flota.

**Pregunta guía:** ¿cómo garantizamos las mismas reglas de negocio desde la interfaz Salesforce, las cargas masivas y futuras integraciones?

<!--
TIEMPO: 2 min
-->

---

# 2. Objetivo y alcance de la solución

## Un único proceso de alquiler

1. El operador busca un vehículo.
2. Selecciona fechas y cliente.
3. Consulta precio y disponibilidad antes de guardar.
4. Guarda la reserva: las reglas se vuelven a validar en servidor.
5. Si supera umbrales, entra en aprobación.
6. Al completarse, se factura de forma asíncrona.

**Resultado:** menos errores manuales, reglas centralizadas y trazabilidad.

<!--
TIEMPO: 2 min
-->

---

# 3. Arquitectura: entrada, orquestación y servicios

```text
LWC Rental Console / Fleet Search
              |
        Apex Controllers
              |
VRT_TRG_Rental -> VRT_TRG_RentalHandler
       | before                 | after
       v                        v
Pricing + Availability       Approval Manager
                              Invoice Queueable
```

- Un trigger por objeto, sin lógica de negocio.
- Handler para enrutar el contexto.
- Services independientes y testeables.

<!--
TIEMPO: 2 min
REFERENCIAS: VRT_TRG_Rental, VRT_TRG_RentalHandler y las clases VRT_SRV_*.
-->

---

# 4. Modelo de datos y responsabilidades

| Área | Datos principales | Responsabilidad |
|---|---|---|
| Cliente | `Account` | Historial y fidelidad |
| Flota | `VRT_Vehicle__c` | Tipo, estado y disponibilidad |
| Reserva | `VRT_Rental__c` | Fechas, estado y coste |
| Tarifas | `VRT_Tarifa__c` | Precio administrable |
| Finanzas | `VRT_Factura__c` | Factura generada |
| Auditoría | `VRT_LogProceso__c` | Resultado del proceso |

**Decisión:** las tarifas son datos administrables, no constantes enterradas en el código.

<!--
TIEMPO: 2 min
-->

---

# 5. Motor de precios dinámicos

`VRT_SRV_PricingEngine.calculateTotalCost(List<VRT_Rental__c>)`

```text
coste base = tarifa por día x duración
coste con fidelidad = coste base x 0,95
coste total = coste con fidelidad + penalización
```

- Temporada calculada a partir de la fecha de inicio.
- Tarifa indexada por `temporada + tipo de vehículo`.
- 5% de descuento desde 3 alquileres en los últimos 12 meses.
- 25% por día de retraso.
- Redondeo final a dos decimales.

**Importante:** el método recibe una lista y está diseñado para bulk.

<!--
TIEMPO: 3 min
DEMO: mostrar una tarifa, crear una reserva y cambiar las fechas para enseñar la simulación.
-->

---

# 6. Disponibilidad: la regla que protege el inventario

## Regla de solapamiento

```text
inicio_nuevo < fin_existente
AND
fin_nuevo > inicio_existente
```

- Se consulta una sola vez por lote y se agrupa por vehículo.
- Se excluyen los registros que se están actualizando.
- Se detectan conflictos contra la base de datos y dentro del mismo lote.
- Se permite continuidad: un alquiler puede terminar el mismo día que empieza el siguiente.
- El error se devuelve con `addError()` en `before insert/update`.

**La UI ayuda; el trigger garantiza.**

<!--
TIEMPO: 3 min
DEMO: intentar una fecha solapada y después una fecha contigua.
-->

---

# 7. Aprobaciones financieras

Después de guardar, `VRT_SRV_ApprovalManager` evalúa el importe:

- **Más de 3.000 €:** aprobación de gerente.
- **Más de 10.000 €:** gerente + responsable financiero.
- Registro bloqueado durante la aprobación.
- Rechazo: reserva cancelada y motivo trazable.

**Por qué declarativo:** el flujo de aprobación, responsables y bloqueo son configuración de negocio; Apex decide cuándo enviar, no replica el motor de aprobaciones.

<!--
TIEMPO: 1 min
-->

---

# 8. Consola operativa LWC

## `vrtRentalConsole`

- Embebida en la página de Account.
- Tabla de alquileres y KPIs agregados.
- Filtros y creación inline.
- Precio y disponibilidad en vivo.
- Resultado reactivo sin recarga completa.
- Errores visibles como feedback de usuario.

### Decisión clave

La simulación crea un `VRT_Rental__c` temporal en memoria, inyecta la duración de la fórmula y llama al motor sin DML.

**Simular no es guardar.**

<!--
TIEMPO: 2 min
DEMO: abrir una Account, enseñar KPIs, cambiar fechas y observar el precio antes de guardar.
-->

---

# 9. Buscador global de flota

## `vrtFleetSearch`

- Disponible desde Home.
- Busca por marca, modelo o matrícula.
- Debounce de 300 ms.
- Mínimo de 2 caracteres.
- Límite de 50 resultados.
- Tarjetas con tipo, estado y disponibilidad.
- Navegación directa al registro del vehículo.

**UX y rendimiento:** no se consulta en cada pulsación y se evita una búsqueda vacía o demasiado amplia.

<!--
TIEMPO: 3 min
DEMO: buscar por marca y matrícula; abrir el registro.
-->

---

# 10. Facturación asíncrona

## `VRT_SRV_InvoiceGenerator implements Queueable`

Cuando el alquiler cumple la condición de facturación:

1. Se encola el trabajo.
2. Se recuperan reservas y facturas existentes.
3. Se evita duplicar una factura.
4. Se insertan facturas con `Database.insert(..., false)`.
5. Se prepara el email al cliente.
6. Se registra éxito o error en `VRT_LogProceso__c`.

**Trade-off:** el usuario no espera a la factura, pero la UI debe comunicar que el resultado es eventual y el log permite auditarlo.

<!--
TIEMPO: 2 min
-->

---

# 11. Seguridad y calidad

## Seguridad

- Controladores `with sharing`.
- Consultas de los LWC con `WITH USER_MODE`.
- Validación de CRUD/FLS en el contexto del usuario.
- Parámetros enlazados y búsqueda acotada.

## Calidad

- Trigger → Handler → Service.
- Sin SOQL/DML dentro de bucles de negocio.
- Métodos bulk y estructuras `Set`/`Map`.
- Fábrica de datos de test.
- Escenarios positivos, negativos, de límite y bulk.

<!--
TIEMPO: 2 min
-->

---

# 12. Estrategia de pruebas y despliegue

## Qué probaría en la demo

- Precio base, fidelidad y retraso.
- Solapamiento y continuidad de fechas.
- Batch de 200 reservas.
- Umbrales de aprobación.
- Factura duplicada y error parcial.
- Acceso de usuario sin FLS.

## Flujo DX

```bash
sf project deploy start
sf apex run --file scripts/apex/insertSampleData.apex
sf apex run test --code-coverage --result-format human --wait 10
sf org open
```

**Evidencia del repositorio:** suite Apex persistida y documentación de cobertura objetivo superior al 85%.

<!--
TIEMPO: 2 min
NOTA: si se enseña una cifra de cobertura, ejecutar la suite en la org actual y mostrar el resultado de ese momento.
-->

---

# 13. Decisiones, trade-offs y evolución

## Decisiones

- Reglas críticas en servidor, no solo en LWC.
- Servicios pequeños en lugar de un trigger monolítico.
- Queueable para desacoplar factura y email.
- Tarifas configurables como datos.
- Declarativo para aprobaciones.

## Siguientes pasos

- Idempotencia reforzada con un campo externo único.
- Monitorización de jobs y alertas operativas.
- Permisos explícitos también en escrituras sensibles.
- Pruebas de límites y volumen en una org de referencia.
- Control de concurrencia para reservas simultáneas.

<!--
TIEMPO: 2 min
-->

---

# 14. Cierre: qué demuestra el proyecto

## No es solo una pantalla de reservas

Es un flujo Salesforce completo:

- **Modelo** para representar el negocio.
- **Apex** para reglas consistentes y bulk-safe.
- **LWC** para una operación rápida.
- **Declarativo** para aprobaciones.
- **Asincronía** para facturación.
- **Seguridad y pruebas** para poder evolucionar.

**Mensaje final:** la plataforma absorbe la complejidad y el usuario opera con una experiencia sencilla.

**Preguntas**

<!--
TIEMPO: 1 min
-->
