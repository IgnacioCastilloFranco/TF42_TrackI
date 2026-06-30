# Scripts

Esta carpeta contiene utilidades para cargar datos de ejemplo en la org.

## Carga de datos de ejemplo

El script [apex/insertSampleData.apex](apex/insertSampleData.apex) inserta los registros de los CSV de [/data](../data) en la org actual:

| Objeto              | Registros | Origen                          |
| ------------------- | --------- | ------------------------------- |
| `Account`           | 5         | [data/accounts.csv](../data/accounts.csv) |
| `VRT_Vehicle__c`    | 10        | [data/vehicles.csv](../data/vehicles.csv) |
| `VRT_Rental__c`     | 21        | [data/rentals.csv](../data/rentals.csv)   |

### Cómo se ejecuta

Asegúrate de tener una org por defecto autorizada (`sf org login web` si todavía no la tienes) y ejecuta desde la raíz del proyecto:

```bash
sf apex run -f scripts/apex/insertSampleData.apex
```

Para apuntar a una org concreta:

```bash
sf apex run -f scripts/apex/insertSampleData.apex -o <alias-de-la-org>
```

### Qué hace el script

1. **Upsert de `Account`** usando `VRT_TXT_ExternalId__c` como External Id (puede ejecutarse varias veces sin duplicar).
2. **Upsert de `VRT_Vehicle__c`** usando `VRT_TXT_ExternalId__c` como External Id.
3. Construye dos mapas `External Id → Salesforce Id` para los Accounts y Vehicles.
4. **Insert de `VRT_Rental__c`** resolviendo los lookups `VRT_LKP_Account__c` y `VRT_LKP_Vehicle__c` desde esos mapas.

> Los Accounts y Vehicles se hacen con `upsert`, así que puedes relanzar el script sin generar duplicados. Los Rentals sí se insertan siempre nuevos: si quieres una carga limpia, borra los existentes primero.

### Si modificas los CSV

El script tiene los datos **en línea** para evitar tener que subir los CSV a la org. Si cambias los CSV de [/data](../data), recuerda reflejar los cambios en `insertSampleData.apex` para mantenerlos sincronizados.
