# Modelo Técnico — Sistema de Administración de Condominio

**Versión:** 0.3
**Estado:** Diseño técnico
**Fecha:** 10 de agosto de 2026

---

# 1. Objetivo

Este documento traduce el modelo de dominio definido para el sistema de administración de condominio a una estructura técnica orientada a DDD, manteniendo una arquitectura sencilla y adecuada para las características actuales del sistema.

El sistema será:

* Monolítico.
* No distribuido.
* Utilizado por un solo usuario a la vez.
* Persistido en PostgreSQL.
* Operado mediante Stored Procedures para las operaciones que requieran coordinación transaccional.
* Expuesto posteriormente mediante una API REST y una interfaz Blazor.

El uso de DDD se limitará a los conceptos que aporten valor real al dominio. No se crearán abstracciones únicamente por seguir patrones de DDD.

---

# 2. Arquitectura conceptual

La solución se organizará conceptualmente en:

```text
Domain
    Entities
    Value Objects
    Aggregates
    Domain Services

Application
    Use Cases
    Transaction Coordination
    DTOs

Infrastructure
    PostgreSQL
    Repositories
    Stored Procedures

API
    REST Endpoints

Blazor UI
    User Interface
```

La capa `Domain` no tendrá conocimiento de PostgreSQL, repositorios ni infraestructura.

---

# 3. Principios técnicos

## 3.1 El dominio no consulta persistencia

Las entidades y Domain Services no realizarán consultas a repositorios para validar información externa.

Cuando una operación necesite información adicional, la Application Layer obtendrá los datos necesarios y los proporcionará al dominio.

Ejemplo:

```text
Application
    │
    ├── obtiene datos
    │
    ▼
Domain Service
    │
    └── aplica reglas
```

Esto evita que las entidades tengan dependencias hacia infraestructura.

---

# 4. Entities

Las principales entidades del dominio serán:

```text
Owner
Department
ServiceCatalog
RecurringService
Charge
Payment
Reservation
Amenity
DepartmentOwnerHistory

Maintenance periods are represented by Reservation records with a
maintenance ServiceCatalog entry.
```

No todas las entidades serán Aggregate Roots.

---

# 5. Aggregates

Los Aggregate Roots definidos son:

```text
Charge
Reservation
```

## 5.1 Charge Aggregate

```text
Charge Aggregate
│
├── Charge          ← Aggregate Root
│
└── Payment         ← Entity
```

`Charge` será responsable de proteger las reglas relacionadas con su estado económico y sus pagos.

## 5.2 Reservation Aggregate

```text
Reservation Aggregate
│
└── Reservation    ← Aggregate Root
```

`Reservation` será responsable de proteger su propio ciclo de vida.

---

# 6. Entidades que no son Aggregate Roots

Las siguientes entidades no serán Aggregate Roots:

```text
Department
RecurringService
Amenity
DepartmentOwnerHistory
Owner
ServiceCatalog
Payment
```

La existencia de reglas de negocio no implica automáticamente que una entidad deba ser Aggregate Root.

El criterio utilizado es el límite de consistencia que necesita proteger cada objeto.

---

# 7. Charge Aggregate

`Charge` es el Aggregate más importante del dominio de Billing.

## 7.1 Responsabilidades

Debe proteger:

* Estado del cargo.
* Transiciones de estado.
* Importe original.
* Importe actualmente exigible.
* Reglas de pago.
* Condonaciones.
* Cancelaciones.
* Relación con sus pagos.

---

# 8. Charge State

Los estados persistidos serán:

```text
Pending
Paid
Waived
Cancelled
```

Las transiciones válidas son:

```text
Pending
   │
   ├──► Paid
   │
   ├──► Waived
   │
   └──► Cancelled
```

Los estados siguientes son terminales:

```text
Paid
Waived
Cancelled
```

No existen transiciones desde un estado terminal hacia otro estado.

---

# 9. Charge.Pay()

La liquidación de un cargo se realizará mediante una operación del Aggregate:

```text
Charge.Pay(payment)
```

Reglas:

* El cargo debe estar en `Pending`.
* El pago debe corresponder al cargo.
* No se permiten pagos parciales.
* El importe del pago debe ser igual al importe actualmente exigible.
* Un cargo `Paid` no puede recibir otro pago.
* Un cargo `Waived` no puede recibir un pago.
* Un cargo `Cancelled` no puede recibir un pago.

Si la operación es válida:

```text
Payment
   ↓
agregado al Charge
   ↓
Charge.Status = Paid
```

El consumidor externo no deberá modificar directamente `Charge.Status`.

---

# 10. Payment

`Payment` será una Entity perteneciente al `Charge Aggregate`.

Relación:

```text
Charge 1 ─────── * Payment
```

Cada `Payment` pertenece exactamente a un `Charge`.

No existirá un Aggregate Root independiente de `Payment`.

## 10.1 Atributos

```text
Payment
-------------------------
Id
ChargeId
PaymentDate
Amount
PaymentMethod
Reference
Notes
```

Todos los datos de un pago serán obligatorios.

## 10.2 PaymentMethod

Los valores iniciales serán:

```text
Cash
Card
Transfer
Other
```

`PaymentMethod` será un tipo simple de clasificación.

No se implementará inicialmente como Value Object porque actualmente no existen reglas de negocio específicas para cada método.

## 10.3 Reference

`Reference` será un texto obligatorio que el administrador podrá utilizar libremente para identificar el pago.

Ejemplos:

```text
"Transferencia BBVA 12345"
"Recibo 2026-0087"
"Pago efectivo"
"Tarjeta terminación 4521"
```

---

# 11. Charge Amounts

`Charge` tendrá:

```text
OriginalAmount
Amount
```

## OriginalAmount

Representa el importe original del cargo.

Una vez creado, no cambia.

## Amount

Representa el importe actualmente exigible.

Puede modificarse mediante operaciones explícitas del dominio.

No se permitirá modificarlo directamente desde fuera del Aggregate.

Ejemplo:

```text
Cargo normal:

OriginalAmount = 1500
Amount         = 1500
Status         = Pending
```

Después de una condonación:

```text
OriginalAmount = 1500
Amount         = 0
Status         = Waived
```

Por lo tanto:

> `OriginalAmount` conserva el valor económico original, mientras que `Amount` representa el importe actualmente exigible.

---

# 12. Charge.Waive()

La condonación se realizará mediante:

```text
Charge.Waive()
```

Reglas:

* El cargo debe estar `Pending`.
* `OriginalAmount` no cambia.
* `Amount` pasa a `0`.
* `Status` pasa a `Waived`.

Ejemplo:

```text
OriginalAmount = 1500
Amount         = 0
Status         = Waived
```

Un cargo `Waived` no se considera `Paid`.

No se genera un `Payment`.

---

# 13. Cargos de $0

Los cargos de importe cero se consideran condonados.

Por lo tanto:

```text
Amount = 0
        ↓
Status = Waived
```

No se registra un pago de `$0`.

Esto permite que servicios o amenidades que actualmente son gratuitos puedan posteriormente adquirir una tarifa sin cambiar el modelo.

---

# 14. Charge.Cancel()

La cancelación administrativa de un cargo se realizará mediante:

```text
Charge.Cancel()
```

Reglas:

* El cargo debe estar `Pending`.
* El estado pasa a `Cancelled`.
* `Cancelled` es terminal.
* Un cargo cancelado no puede recibir pagos.

La cancelación de un cargo es diferente a la reversión económica de una operación ya realizada.

---

# 15. ChargeAdjustment

`ChargeAdjustment` representa un movimiento contable que compensa económicamente un cargo existente.

Se utilizará inicialmente para cancelaciones de operaciones que ya generaron un cargo.

Ejemplo:

```text
Charge original
Amount = 1000
Status = Paid
```

Posteriormente se cancela la operación:

```text
ChargeAdjustment
Amount = -1000
Reason = ReservationCancelled
```

El cargo original permanece registrado.

No se modifica el historial.

## Regla

La cancelación económica de una operación no elimina ni modifica el cargo original.

Se registra un movimiento de ajuste.

`ChargeAdjustment` podrá utilizarse posteriormente para otros conceptos, por ejemplo:

```text
Bonificaciones
Otros ajustes
```

pero esos casos pertenecerán a casos de uso futuros.

---

# 16. ChargeOrigin

`ChargeOrigin` será un Value Object.

Los tipos iniciales serán:

```text
RecurringService
Reservation
Extraordinary
```

La combinación entre origen y referencia deberá ser válida.

```text
RecurringService → RecurringServiceId requerido
Reservation      → ReservationId requerido
Extraordinary    → sin referencia
```

Combinaciones inválidas:

```text
RecurringService + null
Reservation + null
```

La intención es evitar que `Charge` tenga que conocer directamente los diferentes tipos de origen.

Esto también facilita incorporar nuevos orígenes en el futuro sin dispersar lógica de validación por el sistema.

---

# 17. Charge — invariantes

Las principales invariantes del Aggregate serán:

```text
CH-001
Un Charge pertenece a un único Department.

CH-002
Un Charge tiene un único origen válido.

CH-003
OriginalAmount no puede modificarse después de crear el Charge.

CH-004
Amount no puede modificarse arbitrariamente.

CH-005
Pending puede pasar a Paid.

CH-006
Pending puede pasar a Waived.

CH-007
Pending puede pasar a Cancelled.

CH-008
Paid es terminal.

CH-009
Waived es terminal.

CH-010
Cancelled es terminal.

CH-011
No existen pagos parciales.

CH-012
Un Payment pertenece a un único Charge.

CH-013
Un Charge Paid no puede recibir otro Payment.

CH-014
Un Charge Waived no puede recibir Payment.

CH-015
Un Charge Cancelled no puede recibir Payment.
```

---

# 18. Reservation Aggregate

`Reservation` será un Aggregate Root independiente de `Charge`.

```text
Reservation Aggregate
│
└── Reservation
```

`Reservation` no contendrá un `Charge`.

La relación se establecerá mediante:

```text
ReservationId
```

en `Charge`.

Esto se debe a que ambos tienen ciclos de vida diferentes.

---

# 19. Reservation State

No se utilizará un estado `Pending`.

La reservación se crea y confirma como parte de una única operación.

Estados:

```text
Confirmed
Cancelled
Completed
```

Transiciones:

```text
Confirmed
    │
    ├──► Cancelled
    │
    └──► Completed
```

`Cancelled` y `Completed` son estados terminales.

---

# 20. Confirmación de Reservation

La confirmación de una reservación y la creación de su cargo forman una sola operación transaccional.

Conceptualmente:

```text
ConfirmReservation
        │
        ├── validar disponibilidad
        │
        ├── Reservation.Confirm()
        │
        ├── Charge.Create(...)
        │
        └── Commit
```

Si cualquier operación falla:

```text
ROLLBACK
```

La reservación y el cargo quedan sin cambios.

---

# 21. Reservation y Charge

`Reservation` y `Charge` son Aggregates independientes.

```text
Reservation Aggregate
        │
        │ ReservationId
        ▼
Charge Aggregate
        │
        └── Payment
```

La Application Layer coordina ambos Aggregates dentro de una misma transacción cuando sea necesario.

Esto permite mantener Aggregates pequeños sin perder atomicidad.

---

# 22. Reservation — disponibilidad

Una amenidad no puede ser reservada cuando existe un conflicto con:

* Otra reservación.
* Un periodo de mantenimiento/bloqueo.

La regla es:

```text
Reservation
     │
     ├── no se solapa con otra Reservation
     │
     └── no se solapa con AvailabilityPeriod
```

La validación requiere consultar información externa al Aggregate.

Por lo tanto, la disponibilidad se validará en la Application Layer / persistencia, no haciendo que `Reservation` consulte repositorios.

---

# 23. Prioridad de disponibilidad

La regla de consistencia será:

> El mantenimiento se registra como una Reservation. Si una reservación ya existe, no puede crearse otra Reservation de mantenimiento que se solape con ella.

La primera operación registrada tiene preferencia.

Ejemplo:

```text
Reservation existente
        ↓
Maintenance solapado
        ↓
rechazado
```

El mismo control aplica cuando la Reservation existente representa mantenimiento.

---

# 24. Cancelación de Reservation

Una reservación confirmada puede cancelarse en cualquier momento.

La operación será:

```text
Reservation.Cancel()
```

La cancelación de la reservación no elimina el registro.

El estado pasa a:

```text
Cancelled
```

Si la reservación ya generó un cargo, la reversión económica se registra mediante un `ChargeAdjustment`.

Ejemplo:

```text
Reservation
Status = Cancelled

Charge
Amount = 1000
Status = Paid

ChargeAdjustment
Amount = -1000
Reason = ReservationCancelled
```

El cargo original y el pago permanecen intactos.

---

# 25. RecurringService

`RecurringService` no será Aggregate Root.

Representa la relación mediante la cual un departamento recibe un servicio recurrente.

```text
RecurringService
-------------------------
Id
DepartmentId
ServiceCatalogId
StartDate
EndDate
```

No almacena el importe del servicio.

El importe se obtiene de `ServiceCatalog` cuando se genera el `Charge`.

---

# 26. ServiceCatalog

`ServiceCatalog` representa los conceptos que pueden generar cargos.

No se limita exclusivamente a servicios recurrentes.

Puede representar:

```text
Mantenimiento
WiFi
Casa Club
Asador
Cargo extraordinario
Otros conceptos
```

Los cargos extraordinarios se registrarán en el catálogo y utilizarán el mismo flujo de `Charge`.

No existirá un mecanismo independiente para `ExtraordinaryCharge`.

---

# 27. ServiceCatalog — tarifa

El catálogo conservará la tarifa correspondiente al servicio.

Los cambios de tarifa afectan únicamente cargos creados posteriormente.

Los cargos existentes conservan sus valores.

Ejemplo:

```text
Antes:
DefaultAmount = 1500

Cargo julio:
Amount = 1500

Nueva tarifa:
DefaultAmount = 1600

Cargo agosto:
Amount = 1600
```

---

# 28. ServiceCatalog — fecha de inicio de aplicación

La fecha a partir de la cual un concepto del catálogo aplica se manejará a nivel de servicio y no a nivel de departamento.

La fecha será común para los departamentos a los que corresponda el servicio.

Esta fecha representa el inicio de aplicación de la configuración del servicio.

Un `RecurringService` no tendrá una fecha independiente para determinar la tarifa general del servicio.

---

# 29. BillingPeriod

El periodo de facturación identifica el mes al que corresponde un cargo recurrente.

Conceptualmente:

```text
Year
Month
```

En persistencia se representará mediante valores enteros correspondientes al año y mes.

No se utilizará una fecha arbitraria, como el primer día del mes, para representar el periodo.

Ejemplo:

```text
BillingPeriod
Year  = 2026
Month = 8
```

---

# 30. StartDate y BillingPeriod

Si:

```text
RecurringService.StartDate = 2026-08-15
BillingPeriod = 2026-08
```

el cargo correspondiente al periodo de agosto se genera por el **mes completo**.

No existe prorrateo.

Por lo tanto:

```text
StartDate = 2026-08-15
BillingPeriod = 2026-08
```

produce el cargo completo de agosto.

---

# 31. GenerateRecurringCharges

`GenerateRecurringCharges` será un Domain Service.

Su responsabilidad será determinar qué cargos recurrentes deben crearse.

No tendrá acceso directo a repositorios ni infraestructura.

Recibirá toda la información necesaria:

```text
BillingPeriod
RecurringServices
ServiceCatalog
ExistingCharges
CondominiumSettings
```

y devolverá los nuevos `Charge` que deben persistirse.

---

# 32. GenerateRecurringCharges — flujo

Conceptualmente:

```text
Application
    │
    ├── obtiene RecurringServices
    ├── obtiene ServiceCatalog
    ├── obtiene Existing Charges
    ├── obtiene CondominiumSettings
    │
    ▼
GenerateRecurringCharges
    │
    ├── determina servicios aplicables
    ├── determina tarifa
    ├── determina DueDate
    ├── verifica cargos existentes
    │
    ▼
New Charges
    │
    ▼
Repository / PostgreSQL
```

El Domain Service no:

```text
consulta PostgreSQL
llama repositorios
guarda cargos
```

---

# 33. Idempotencia

La generación de cargos recurrentes será idempotente.

Para:

```text
RecurringService + BillingPeriod
```

debe existir como máximo un cargo.

Ejecutar:

```text
GenerateRecurringCharges(2026, 8)
```

una o varias veces debe producir el mismo resultado final.

La idempotencia se protegerá en dos niveles:

```text
Domain/Application
        +
PostgreSQL UNIQUE constraint
```

La restricción de base de datos será la garantía definitiva de integridad.

---

# 34. DueDate

`DueDate` se calcula al crear el `Charge`.

La configuración utilizada será:

```text
CondominiumSettings.PaymentDueDay
```

Ejemplo:

```text
PaymentDueDay = 5
BillingPeriod = 2026-08
```

produce:

```text
DueDate = 2026-08-05
```

Una vez creado el cargo, `DueDate` queda congelado.

Cambios posteriores en `CondominiumSettings` no modifican cargos existentes.

---

# 35. Overdue

No se persistirá inicialmente un estado `Overdue`.

Un cargo se considera vencido cuando:

```text
Status = Pending
AND
CurrentDate > DueDate
```

El vencimiento ocurre inmediatamente después de `DueDate`.

No existe actualmente un periodo de tolerancia.

Ejemplo:

```text
DueDate = 2026-08-05

2026-08-05 → no vencido
2026-08-06 → vencido
```

---

# 36. Department

`Department` no será Aggregate Root.

Representa el inmueble al que pertenecen las obligaciones económicas.

```text
Department
-------------------------
Id
Building
Number
OwnerId
```

Los cargos pertenecen al `Department`, no al `Owner`.

---

# 37. Owner

`Owner` representa al propietario de uno o más departamentos.

Un propietario puede estar relacionado con múltiples departamentos.

El cambio de propietario no modifica los cargos ni pagos históricos.

---

# 38. DepartmentOwnerHistory

Se conservará un historial de propietarios.

```text
DepartmentOwnerHistory
-------------------------
Id
DepartmentId
OwnerId
StartDate
EndDate?
```

El propietario actual tendrá:

```text
EndDate = NULL
```

Esto constituye una excepción deliberada a la regla general de evitar campos nulos.

En este caso `NULL` tiene una semántica clara:

> El propietario actual no tiene todavía una fecha de finalización.

Los propietarios anteriores tendrán una fecha de finalización.

---

# 39. ChangeOwner

El cambio de propietario se realizará como una única operación transaccional.

Conceptualmente:

```text
ChangeOwner
    │
    ├── crear Owner si es necesario
    ├── cerrar OwnerHistory anterior
    ├── actualizar Department.OwnerId
    └── crear OwnerHistory nuevo
```

Los `Charge` y `Payment` históricos no se modifican.

El historial económico permanece asociado al `Department`.

---

# 40. Amenity

`Amenity` no será Aggregate Root.

Representa una amenidad administrada por el condominio.

```text
Amenity
-------------------------
Id
Name
Description
Location
```

La lógica de reservación y disponibilidad se encuentra en `Reservation`. Los periodos de mantenimiento y bloqueo se registran como Reservations con un ServiceCatalog de mantenimiento.

---

# 41. Domain Services

El único Domain Service identificado actualmente es:

```text
GenerateRecurringCharges
```

Las siguientes operaciones serán casos de uso de Application Layer y no Domain Services:

```text
CreateReservation
CancelReservation
ChangeOwner
RegisterPayment
CancelCharge
GenerateChargeAdjustment
```

La existencia de varias entidades involucradas no es suficiente para convertir una operación en Domain Service.

---

# 44. Domain Events

No se implementarán Domain Events inicialmente.

No son necesarios porque:

* el sistema no es distribuido;
* existe un solo usuario simultáneo;
* las operaciones se ejecutan dentro de una misma aplicación;
* las operaciones relacionadas requieren transacciones inmediatas;
* no existen actualmente consumidores independientes que necesiten reaccionar a eventos.

No se implementarán inicialmente:

```text
ReservationConfirmed
ReservationCancelled
ChargePaid
ChargeWaived
PaymentRegistered
OwnerChanged
```

Si en el futuro aparecen necesidades como notificaciones, integraciones externas o procesamiento desacoplado, se podrá reevaluar esta decisión.

---

# 45. Application Layer

La Application Layer será responsable de coordinar los casos de uso y los límites transaccionales.

Casos de uso principales:

```text
GenerateRecurringCharges
RegisterPayment
CreateReservation
CancelReservation
ChangeOwner
CancelCharge
```

La Application Layer:

* obtiene información de persistencia;
* prepara los datos necesarios para el dominio;
* invoca entidades y Domain Services;
* coordina varios Aggregates cuando sea necesario;
* controla la transacción.

---

# 46. Repositories

Los repositorios estarán orientados principalmente a Aggregates.

Se evitará crear repositorios innecesarios para cada Entity simplemente porque exista una tabla.

Por ejemplo:

```text
ChargeRepository
ReservationRepository
```

son conceptos naturales.

En cambio, no es necesario que exista obligatoriamente:

```text
PaymentRepository
```

porque `Payment` pertenece al `Charge Aggregate`.

Las consultas de lectura podrán utilizar mecanismos independientes de los Aggregates cuando resulte más eficiente.

---

# 47. Consultas de lectura

DDD no obliga a utilizar Aggregates para todas las consultas.

Para operaciones como:

```text
Estado de cuenta
Historial de pagos
Pagos de un departamento
Reservaciones
```

se podrán realizar consultas directas optimizadas sobre PostgreSQL.

El Aggregate se utilizará principalmente para operaciones que modifiquen el estado y necesiten proteger invariantes.

---

# 48. Persistencia y Stored Procedures

Las operaciones que requieran múltiples modificaciones atómicas podrán implementarse mediante Stored Procedures.

Esto es especialmente aplicable a:

```text
ConfirmReservation + Charge
CancelReservation + ChargeAdjustment
ChangeOwner + OwnerHistory
GenerateRecurringCharges
RegisterPayment
```

El hecho de utilizar Stored Procedures no modifica el modelo de dominio.

Para el dominio:

```text
Repository / Persistence
```

es una implementación de infraestructura.

---

# 49. Transacciones

Las operaciones que deban mantener consistencia entre varios Aggregates se ejecutarán dentro de una misma transacción.

Ejemplo:

```text
ConfirmReservation
│
├── Reservation → Confirmed
├── Charge → Created
│
└── COMMIT
```

Si alguna operación falla:

```text
ROLLBACK
```

De forma equivalente:

```text
CancelReservation
│
├── Reservation → Cancelled
├── ChargeAdjustment → Created
│
└── COMMIT
```

---

# 50. Reglas contables

El modelo conserva los movimientos originales.

No se eliminan registros económicos para ocultar operaciones.

Ejemplo:

```text
Charge
+1000

Payment
+1000

ChargeAdjustment
-1000
```

Esto permite mantener trazabilidad.

El concepto del ajuste identifica por qué se realizó la compensación.

---

# 51. Modelo técnico consolidado

```text
                           ┌───────────────┐
                           │     Owner     │
                           └───────┬───────┘
                                   │
                                   ▼
                           ┌───────────────┐
                           │   Department  │
                           └───────┬───────┘
                                   │
                 ┌─────────────────┼─────────────────┐
                 │                 │                 │
                 ▼                 ▼                 ▼
        RecurringService      Reservation      OwnerHistory
                 │                 │
                 │                 │
                 ▼                 ▼
          ServiceCatalog       Charge
                 │                 │
                 │                 ├── Payment
                 │                 │
                 │                 └── ChargeOrigin
                 │
                 ▼
              Charge


Amenity
   │
   ├── Reservation


CondominiumSettings
   │
   └── PaymentDueDay
```

---

# 52. Aggregate Boundaries

Los límites finales definidos son:

```text
Charge Aggregate
-------------------------
Charge
Payment


Reservation Aggregate
-------------------------
Reservation
```

Las demás entidades se manejan fuera de esos Aggregates.

Las relaciones entre Aggregates se realizan mediante identificadores, no mediante referencias directas a objetos completos.

---

# 53. Decisiones de diseño confirmadas

| Decisión                                                            | Estado     |
| ------------------------------------------------------------------- | ---------- |
| Sistema monolítico                                                  | Confirmado |
| Un usuario simultáneo                                               | Confirmado |
| PostgreSQL                                                          | Confirmado |
| Stored Procedures para operaciones transaccionales                  | Confirmado |
| `Charge` es Aggregate Root                                          | Confirmado |
| `Payment` pertenece a `Charge`                                      | Confirmado |
| `Reservation` es Aggregate Root                                     | Confirmado |
| `Reservation` y `Charge` son Aggregates independientes              | Confirmado |
| `Department` no es Aggregate Root                                   | Confirmado |
| `RecurringService` no es Aggregate Root                             | Confirmado |
| `Amenity` no es Aggregate Root                                      | Confirmado |
| `DepartmentOwnerHistory` no es Aggregate Root                       | Confirmado |
| `ChargeOrigin` es Value Object                                      | Confirmado |
| `Money` no es Value Object                                          | Confirmado |
| `BillingPeriod` no es Value Object                                  | Confirmado |
| `PaymentMethod` no es Value Object                                  | Confirmado |
| No Domain Events inicialmente                                       | Confirmado |
| `GenerateRecurringCharges` es Domain Service                        | Confirmado |
| Domain Services no acceden a repositorios                           | Confirmado |
| No pagos parciales                                                  | Confirmado |
| Un Payment pertenece a un Charge                                    | Confirmado |
| `OriginalAmount` no cambia                                          | Confirmado |
| `Amount` puede cambiar mediante comportamiento de dominio           | Confirmado |
| `Waive()` establece `Amount = 0`                                    | Confirmado |
| Cargo de $0 se considera `Waived`                                   | Confirmado |
| Estados terminales de Charge                                        | Confirmado |
| Cancelación económica mediante `ChargeAdjustment`                   | Confirmado |
| `ChargeAdjustment` conserva trazabilidad                            | Confirmado |
| Cargos extraordinarios utilizan `ServiceCatalog`                    | Confirmado |
| Cambios de tarifa afectan cargos futuros                            | Confirmado |
| `DueDate` queda congelado en Charge                                 | Confirmado |
| No existe periodo de tolerancia                                     | Confirmado |
| Overdue se calcula dinámicamente                                    | Confirmado |
| StartDate puede caer dentro del periodo                             | Confirmado |
| StartDate no produce prorrateo                                      | Confirmado |
| Se cobra el mes completo                                            | Confirmado |
| Reservation no tiene Pending                                        | Confirmado |
| Confirmación genera Charge inmediatamente                           | Confirmado |
| Confirmación y Charge ocurren en una transacción                    | Confirmado |
| Cancelación de Reservation permitida en cualquier momento           | Confirmado |
| Cancelación genera ChargeAdjustment cuando existe impacto económico | Confirmado |
| No se permite solapamiento de reservaciones                         | Confirmado |
| No se permite reservación durante mantenimiento/bloqueo             | Confirmado |
| El primer registro tiene prioridad                                  | Confirmado |
| Historial de propietarios                                           | Confirmado |
| `EndDate = NULL` para propietario actual                            | Confirmado |
| Cambio de propietario no modifica historial económico               | Confirmado |
| PaymentMethod inicial                                               | Confirmado |
| Reference de Payment es obligatorio                                 | Confirmado |

---

# 54. Puntos pendientes

Los siguientes puntos todavía requieren decisiones específicas del negocio o implementación y no deben inventarse prematuramente.

## 54.1 Recargos por vencimiento

Definir si los cargos vencidos generan:

* recargo fijo;
* porcentaje;
* cargo adicional;
* o ningún recargo.

---

## 54.2 Reglas detalladas de `ChargeAdjustment`

El mecanismo general está definido, pero todavía debe especificarse el catálogo de razones y las reglas para cada tipo de ajuste.

Actualmente conocemos:

```text
ReservationCancelled
```

y sabemos que en el futuro podrían existir:

```text
Bonus
Other adjustments
```

---

## 54.3 Métodos de pago futuros

Actualmente:

```text
Cash
Card
Transfer
Other
```

No se han definido reglas específicas para cada método.

---

## 54.4 Reglas de cancelación administrativa de Charge

Está definida la transición:

```text
Pending → Cancelled
```

pero falta determinar qué roles o casos de uso pueden ejecutar una cancelación administrativa y si requiere algún motivo obligatorio.

---

## 54.5 Generación de cargos extraordinarios

El concepto ya está definido como un servicio de `ServiceCatalog`.

Falta definir el caso de uso específico para:

```text
CreateExtraordinaryCharge
```

incluyendo permisos y reglas administrativas.

---

## 54.6 Promociones

No existe una entidad `Promotion`.

La promoción de pago anual y condonación ya está soportada mediante:

```text
OriginalAmount
Amount
Waived
```

Pero las reglas exactas para determinar cuándo se concede una promoción todavía deben definirse.

---

## 54.7 Historial de configuración de tarifas

Actualmente los cargos históricos conservan su importe.

Queda pendiente determinar si se necesita conservar un historial explícito de cambios de `ServiceCatalog.DefaultAmount` para fines administrativos o de auditoría.

---

## 54.8 Usuarios y permisos

Todavía deben definirse:

* usuarios administrativos;
* autenticación;
* autorización;
* roles;
* permisos;
* auditoría de acciones administrativas.

---

## 54.9 Auditoría técnica

Debe definirse posteriormente si se requiere un mecanismo adicional de auditoría para registrar:

* quién realizó una operación;
* cuándo la realizó;
* qué valores fueron modificados.

El historial económico no depende de esta decisión.

---

# 55. Próximo paso

El modelo técnico de dominio queda suficientemente definido para comenzar a traducirlo a persistencia.

El siguiente paso recomendado es:

```text
Diseño del esquema PostgreSQL
```

partiendo directamente de:

```text
Aggregates
Entities
Value Objects
Invariantes
Relaciones
```

La implementación de PostgreSQL deberá preservar las invariantes importantes mediante:

```text
PKs
FKs
UNIQUE constraints
CHECK constraints
Indexes
Transactions
Stored Procedures
```

La base de datos será una segunda línea de defensa de las reglas del dominio, especialmente para:

```text
Idempotencia
Integridad referencial
Importes
Estados
Orígenes de Charge
Relaciones entre Charge y Payment
Solapamiento de reservaciones
```

El diseño del esquema deberá realizarse **antes de implementar las entidades C#**, para evitar que la persistencia dicte accidentalmente el modelo de dominio.
