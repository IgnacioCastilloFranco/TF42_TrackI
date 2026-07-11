# AlquilaVehículo S.L. – Salesforce DX Project (Track II)

Este repositorio contiene la evolución funcional y técnica de la aplicación **AlquilaVehículo** orientada a mejorar la escalabilidad, seguridad, automatización y experiencia del equipo operativo.

---

## Estructura de la Evolución Técnica

1. **Fase 1 & 2: Motor de Precios y Disponibilidad**
   - Automatización de precios dinámicos según tipo de vehículo, temporadas, descuentos por fidelidad y penalizaciones por retraso.
   - Control estricto de disponibilidad para prevenir solapamientos de reservas.
2. **Fase 3: Aprobaciones Financieras**
   - Proceso de aprobación escalonado según el importe del alquiler (Gerente para > 3.000€ y doble aprobación para > 10.000€).
3. **Fase 4: Consola Operativa (LWC)**
   - Consola Lightning Web Component integrada en el detalle de la Cuenta. Permite visualizar KPIs consolidados, filtrar por estado, y crear alquileres con simulación reactiva de precio y disponibilidad en vivo sin recargas.
4. **Fase 5: Facturación Automática**
   - Procesamiento asíncrono vía Queueable Apex para generar facturas (`VRT_Factura__c`), enviar notificaciones por correo y registrar trazas de logs de auditoría (`VRT_LogProceso__c`) al completar alquileres.
5. **Fase 6: Buscador Global de Flota**
   - Componente expuesto en la página de inicio (Home Page) para búsquedas de vehículos por coincidencia parcial de marca, modelo o matrícula, con visualización premium de tarjetas.
6. **Fase 7: Testing y Calidad**
   - Clase centralizada `VRT_TestDataFactory` para pruebas unitarias. Suite completa de pruebas con una cobertura general superior al **96%**.

---

## Pasos de Despliegue en la Org

Para desplegar y configurar este proyecto utilizando la CLI de Salesforce (`sf`), sigue estos pasos:

### 1. Clonar el repositorio y acceder al directorio
Asegúrate de que estás en la raíz del proyecto.

### 2. Iniciar sesión en tu Org de Salesforce
Si aún no estás autenticado en tu Org destino (Scratch Org o Developer Edition), ejecuta:
```bash
sf org login web -a AlquilaVehiculoOrg
```

### 3. Desplegar los Metadatos y el Código a la Org
Despliega la totalidad del código y personalizaciones de la carpeta `force-app`:
```bash
sf project deploy start
```

### 4. Cargar los Datos de Prueba (Sample Data)
Para poblar la base de datos de tu Org con cuentas, vehículos, tarifas y reservas de ejemplo, ejecuta el script Apex anónimo disponible:
```bash
sf apex run --file scripts/apex/insertSampleData.apex
```

### 5. Ejecutar la Suite de Pruebas Unitarias
Para validar que todo se ha desplegado correctamente y comprobar la cobertura de código:
```bash
sf apex run test --code-coverage --result-format human --wait 10
```

### 6. Abrir la Org en tu Navegador
Accede de manera directa a la aplicación en Salesforce Experience:
```bash
sf org open
```
*Nota: Puedes añadir el componente LWC de la consola a la página de Cuenta mediante el App Builder, o consultar el buscador de flota desde la Home Page.*

