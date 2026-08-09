# Modelo de Dominio — Sistema de Administración de Condominio

**Versión:** 0.2
**Estado:** Borrador de diseño
**Fecha:** 8 de agosto de 2026

---

# 1. Objetivo

Este documento define el modelo de dominio inicial del sistema de administración de condominio.

Su propósito es establecer los principales conceptos del negocio, sus responsabilidades, relaciones y reglas de negocio antes de implementar la persistencia en PostgreSQL y la API REST.

El modelo deberá evolucionar conforme se descubran nuevas reglas del negocio.

---

# 2. Contextos funcionales

El dominio se divide conceptualmente en tres áreas principales:

```text
Condominium Management
│
├── Property Management
│   ├── Owner
│   ├── Department
│   └── CondominiumSettings
│
├── Billing
│   ├── ServiceCatalog
│   ├── RecurringService
│   ├── Charge
│   └── Payment
│
└── Amenities
    ├── Amenity
    ├── Reservation
    ├── AmenityMaintenance
    └── AmenityAvailabilityPeriod
```

Estos contextos representan una separación conceptual del dominio. No implican necesariamente que cada uno deba convertirse en un microservicio o proyecto independiente.

---

# 3. Property Management

## 3.1 Owner

Representa al propietario de uno o más departamentos.

### Atributos iniciales

```text
Owner
-------------------------
Id
Name
Phone
Email
...
```

### Relaciones

```text
Owner 1 ─────── * Department
```

Un propietario puede estar asociado con uno o más departamentos.

El sistema deberá poder consultar los cargos y pagos relacionados con los departamentos de un propietario.

---

# 4. Department

Representa un departamento físico del condominio.

### Atributos iniciales

```text
Department
-------------------------
Id
Building
Number
OwnerId
Active
```

El departamento será la entidad a la que se asignarán las obligaciones económicas.

### Regla

Los cargos pertenecen al `Department`, no directamente al `Owner`.

Esto permite que el estado de cuenta sea construido a partir del inmueble y que el propietario pueda consultar posteriormente la información de sus departamentos.

---

# 5. CondominiumSettings

Representa la configuración general del condominio.

### Atributos iniciales

```text
CondominiumSettings
-------------------------
PaymentDueDay
```

`PaymentDueDay` representa el día del mes en que vencen los pagos y aplica de manera uniforme a todos los departamentos.

Ejemplo:

```text
PaymentDueDay = 5
```

Entonces los cargos del periodo agosto tendrán como fecha de vencimiento:

```text
2026-08-05
```

### Regla

El `Charge` conservará la fecha de vencimiento calculada al momento de su creación.

Cambios posteriores en `CondominiumSettings` no modificarán automáticamente cargos existentes.

---

# 6. Billing

El dominio de facturación se basa en la separación:

```text
ServiceCatalog
      │
      ▼
RecurringService / Reservation
      │
      ▼
Charge
      │
      ▼
Payment
```

El concepto central es `Charge`.

Un servicio define qué se ofrece.

Un cargo representa qué debe pagar un departamento.

Un pago representa la liquidación de uno o más cargos.

---

# 7. ServiceCatalog

Representa un servicio disponible en el condominio.

Ejemplos:

* Mantenimiento.
* WiFi.
* Renta de casa club.
* Renta de asador.
* Otros servicios futuros.

### Atributos iniciales

```text
ServiceCatalog
-------------------------
Id
Name
Description
Type
DefaultAmount
Active
```

## 7.1 ServiceType

Los servicios podrán clasificarse inicialmente como:

```text
Recurring
Event
OneTime
```

### Recurring

Servicios que se generan periódicamente.

Ejemplos:

* Mantenimiento.
* WiFi.

### Event

Servicios asociados a un evento o reservación.

Ejemplos:

* Casa club.
* Asador.

### OneTime

Servicios o cargos extraordinarios que ocurren una sola vez.

---

# 8. ServiceCatalog.DefaultAmount

`DefaultAmount` representa la tarifa vigente del servicio.

Para los servicios que actualmente se conocen:

```text
Mantenimiento → tarifa común
WiFi          → tarifa común
Casa Club     → tarifa definida por catálogo
Asador        → tarifa definida por catálogo
```

La tarifa será común para todos los departamentos cuando el servicio así lo establezca.

## Regla de negocio

Los cambios en `DefaultAmount` solamente afectarán cargos creados después del cambio.

Los cargos existentes conservarán el importe que tenían al momento de su creación.

Ejemplo:

```text
Mantenimiento

Antes:
DefaultAmount = $1,500

Cargo de julio:
Amount = $1,500

Cambio de tarifa:
DefaultAmount = $1,600

Cargo de agosto:
Amount = $1,600

Cargo de julio:
continúa en $1,500
```

---

# 9. RecurringService

Representa la configuración mediante la cual un departamento recibe periódicamente un servicio.

### Atributos iniciales

```text
RecurringService
-------------------------
Id
DepartmentId
ServiceCatalogId
StartDate
EndDate
Active
```

Ejemplo:

```text
Departamento: A-101
Servicio: Mantenimiento
Inicio: 2026-01-01
Activo: true
```

`RecurringService` no necesita almacenar el importe cuando todos los departamentos utilizan la misma tarifa.

El importe se obtiene del `ServiceCatalog` al momento de generar el cargo.

Una vez creado el `Charge`, el importe queda almacenado en éste.

---

# 10. Charge

`Charge` representa una obligación económica concreta de un departamento.

Es el concepto central del dominio de Billing.

### Atributos iniciales

```text
Charge
-------------------------
Id
DepartmentId
ServiceCatalogId
RecurringServiceId?
ReservationId?

Period?
DueDate

OriginalAmount
Amount

Status

CreatedAt
Notes
```

Las referencias opcionales permiten identificar el origen del cargo.

Un cargo puede originarse por:

* Servicio recurrente.
* Reservación.
* Cargo extraordinario.

---

# 11. Charge.Amount

`Amount` representa la cantidad que efectivamente debe pagar el departamento.

El valor se determina en el momento de creación del cargo.

Una modificación posterior en `ServiceCatalog.DefaultAmount` no modifica el `Charge`.

---

# 12. Charge.OriginalAmount

`OriginalAmount` representa el importe que normalmente correspondía al cargo antes de descuentos o condonaciones.

Para un cargo normal:

```text
OriginalAmount = $1,500
Amount = $1,500
```

Para un cargo condonado:

```text
OriginalAmount = $1,500
Amount = $0
```

Esto permite conservar información sobre el valor económico original del cargo.

También permite soportar posteriormente descuentos o promociones más complejas sin perder el importe original.

---

# 13. BillingPeriod

Los cargos recurrentes estarán asociados a un periodo de facturación.

Conceptualmente:

```text
BillingPeriod
-------------------------
Year
Month
```

Ejemplo:

```text
2026-08
```

El periodo identifica el mes al que corresponde un cargo recurrente.

No se deberá utilizar una fecha arbitraria para representar el periodo.

---

# 14. ChargeStatus

Los estados iniciales serán:

```text
Pending
Paid
Waived
Cancelled
```

## Pending

El cargo representa una obligación pendiente de pago.

## Paid

El cargo fue completamente liquidado mediante uno o más pagos asociados.

## Waived

El cargo fue condonado y ya no representa una cantidad pendiente de pago.

## Cancelled

El cargo fue cancelado administrativamente.

---

# 15. Cargos vencidos

Un cargo `Pending` cuya fecha de vencimiento ya pasó podrá considerarse vencido:

```text
Status = Pending
Today > DueDate
        ↓
Overdue
```

En esta versión `Overdue` no se considera necesariamente un estado persistido.

Podrá calcularse dinámicamente a partir de:

* Estado del cargo.
* Fecha actual.
* Fecha de vencimiento.

La decisión final sobre persistir o calcular este estado queda pendiente.

---

# 16. Condiciones especiales: condonaciones

El sistema deberá soportar cargos condonados.

Un caso conocido es la promoción mediante la cual un departamento paga por adelantado el mantenimiento anual y recibe un mes de mantenimiento gratuito.

Ejemplo:

```text
Mantenimiento mensual = $1,500
```

Se generan los doce cargos del año:

```text
Enero      $1,500
Febrero    $1,500
Marzo      $1,500
Abril      $1,500
Mayo       $1,500
Junio      $1,500
Julio      $1,500
Agosto     $1,500
Septiembre $1,500
Octubre    $1,500
Noviembre  $1,500
Diciembre  $0
```

El cargo de diciembre conservará:

```text
OriginalAmount = $1,500
Amount = $0
Status = Waived
```

y podrá contener:

```text
Reason = AnnualPrepaymentPromotion
Notes = "Condonación por pago adelantado"
```

## Regla importante

Un cargo condonado **no se considera pagado**.

La diferencia conceptual es:

```text
Paid   → la obligación fue liquidada mediante dinero.
Waived  → la obligación fue eliminada/condonada.
```

Por esta razón no deberá utilizarse `Paid` para representar una condonación.

---

# 17. Payment

Representa un pago realizado por un departamento.

### Atributos iniciales

```text
Payment
-------------------------
Id
PaymentDate
Amount
PaymentMethod
Reference
Notes
```

Un pago podrá liquidar uno o más cargos.

Esto es necesario para soportar pagos anticipados.

---

# 18. Regla de pagos

Un cargo no puede recibir pagos parciales.

Un cargo pasa de Pending a Paid únicamente cuando se liquida en su totalidad.

Cada pago se asocia a un único cargo.

Para pagos anticipados (ej. anual), el administrador registra múltiples pagos individuales, uno por cada cargo, y el cargo condonado se marca como Waived.

---

# 19. Generación de cargos recurrentes

La aplicación no dependerá de un proceso ejecutándose permanentemente.

La generación de cargos será una operación iniciada por el administrador.

Conceptualmente:

```text
GenerateCharges(BillingPeriod)
```

El proceso deberá:

1. Obtener los servicios recurrentes activos.
2. Determinar los cargos que corresponden al periodo.
3. Obtener la tarifa vigente de cada servicio.
4. Obtener la fecha de vencimiento configurada para el condominio.
5. Verificar si el cargo ya existe.
6. Crear únicamente los cargos faltantes.
7. Mantener los cargos históricos sin modificaciones.

---

# 20. Idempotencia de generación

La generación de cargos deberá ser idempotente.

Para una misma combinación:

```text
RecurringService
+
BillingPeriod
```

deberá existir como máximo un cargo.

Ejecutar:

```text
GenerateCharges(2026-08)
```

una o diez veces deberá producir el mismo resultado final.

---

# 21. Amenity

Representa una amenidad o área común administrada por el condominio.

Ejemplos:

* Alberca.
* Casa club.
* Asador.
* Gimnasio.
* Otras zonas comunes.

### Atributos iniciales

```text
Amenity
-------------------------
Id
Name
Description
Location
Active
```

---

# 22. Reservation

Representa una reservación de una amenidad realizada por un departamento.

### Atributos iniciales

```text
Reservation
-------------------------
Id
AmenityId
DepartmentId
StartDateTime
EndDateTime
Status
```

Una reservación podrá generar un `Charge`.

---

# 23. ReservationStatus

Estados iniciales:

```text
Pending
Confirmed
Cancelled
Completed
```

---

# 24. Cargo de una reservación

El cargo asociado a una reservación se generará inmediatamente cuando la reservación sea confirmada.

Conceptualmente:

```text
Reservation
     │
     ├── Amenity
     ├── Department
     │
     ▼
   Charge
```

El importe será obtenido de `ServiceCatalog.DefaultAmount`.

---

# 25. Reservaciones gratuitas

Todas las reservaciones deberán generar un cargo, incluso cuando el servicio sea gratuito.

Ejemplo:

```text
Reservation
Casa Club
A-101

        ↓

Charge
OriginalAmount = $0
Amount = $0
Status = Paid
```

Para un servicio gratuito no es necesario registrar un pago monetario.

La interpretación exacta de `Paid` para cargos de $0 deberá definirse en la implementación. La intención es que un cargo de importe cero no aparezca como deuda pendiente.

---

# 26. AmenityMaintenance

Representa un mantenimiento realizado sobre una amenidad.

### Atributos iniciales

```text
AmenityMaintenance
-------------------------
Id
AmenityId
Date
Description
Cost
Notes
```

El mantenimiento de una amenidad no genera automáticamente un cargo a los propietarios.

---

# 27. AmenityAvailabilityPeriod

Representa un periodo durante el cual una amenidad no está disponible.

### Atributos iniciales

```text
AmenityAvailabilityPeriod
-------------------------
Id
AmenityId
StartDateTime
EndDateTime
Reason
Notes
```

Ejemplo:

```text
Amenidad: Casa Club
Inicio: 10/08/2026 08:00
Fin: 12/08/2026 18:00
Motivo: Mantenimiento
```

---

# 28. Aggregates propuestos

Los aggregates iniciales serán:

```text
Owner
Department
CondominiumSettings

ServiceCatalog
RecurringService

Charge
Payment
Amenity
Reservation
AmenityMaintenance
AmenityAvailabilityPeriod
```

`Payment` deberá tratarse como parte del modelo de Billing y se evaluará durante el diseño de aggregates si forma parte del `Charge Aggregate` o si `Payment` debe constituir un aggregate independiente.

La decisión definitiva se tomará antes de implementar las entidades de dominio.

---

# 29. Charge Aggregate

El `Charge` deberá proteger las reglas relacionadas con la liquidación del cargo.

Conceptualmente deberá soportar operaciones como:

```text
Pay(...)
Waive(...)
Cancel(...)
```

El consumidor del dominio no debería modificar directamente:

```text
Charge.Status
```

para saltarse las reglas de negocio.

Ejemplo conceptual:

```csharp
charge.Pay(payment);
```

en lugar de:

```csharp
charge.Status = ChargeStatus.Paid;
```

---

# 30. Invariantes principales

El modelo deberá proteger, como mínimo, las siguientes reglas.

### INV-001

Un cargo pertenece a un único departamento.

### INV-002

Un cargo recurrente corresponde a un único periodo.

### INV-003

No puede existir más de un cargo para la misma combinación:

```text
RecurringService + BillingPeriod
```

### INV-004

El importe de un cargo queda congelado al momento de su creación.

### INV-005

Cambios futuros en `ServiceCatalog.DefaultAmount` no afectan cargos existentes.

### INV-006

Un cargo no puede recibir pagos parciales.

### INV-007

Un cargo pagado no puede volver a pagarse.

### INV-008

Un cargo condonado no debe considerarse pagado.

### INV-009

Un cargo cancelado no puede pagarse.

### INV-010

Una reservación confirmada genera inmediatamente su cargo correspondiente.

### INV-011

Una reservación gratuita también genera un cargo de $0.

### INV-012

La fecha de vencimiento de un cargo queda registrada y no cambia automáticamente por cambios posteriores en la configuración del condominio.

---

# 31. Modelo conceptual

```text
                          ┌──────────────┐
                          │    Owner     │
                          └──────┬───────┘
                                 │
                                 ▼
                          ┌──────────────┐
                          │  Department  │
                          └──────┬───────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    ▼                         ▼
          ┌──────────────────┐       ┌────────────────┐
          │RecurringService  │       │  Reservation   │
          └────────┬─────────┘       └───────┬────────┘
                   │                         │
                   │                         │
                   └────────────┬────────────┘
                                ▼
                         ┌─────────────┐
                         │   Charge    │
                         │             │
                         │ OriginalAmt │
                         │ Amount      │
                         │ DueDate     │
                         │ Status      │
                         └──────┬──────┘
                                │
                                ▼
                         ┌─────────────┐
                         │   Payment   │
                         └─────────────┘


          ┌───────────────────────┐
          │    ServiceCatalog     │
          │                       │
          │ DefaultAmount         │
          └───────────┬───────────┘
                      │
             ┌────────┴────────┐
             ▼                 ▼
      RecurringService     Reservation


          ┌──────────────────┐
          │     Amenity      │
          └────────┬─────────┘
                   │
          ┌────────┼───────────────┐
          ▼        ▼               ▼
     Maintenance  Availability  Reservation


          ┌───────────────────────┐
          │ CondominiumSettings   │
          │                       │
          │ PaymentDueDay         │
          └───────────────────────┘

```

---

# 32. Decisiones confirmadas

A partir de la versión 0.2 quedan confirmadas las siguientes decisiones:

| Decisión                                         | Estado     |
| ------------------------------------------------ | ---------- |
| Mantenimiento es recurrente                      | Confirmado |
| WiFi es recurrente                               | Confirmado |
| Tarifas comunes para todos los departamentos     | Confirmado |
| `ServiceCatalog.DefaultAmount`                   | Confirmado |
| Cambios de tarifa afectan cargos futuros         | Confirmado |
| Fecha de pago común para todos                   | Confirmado |
| Fecha de vencimiento queda congelada en `Charge` | Confirmado |
| No existen pagos parciales                       | Confirmado |
| Un pago liquida exactamente un cargo             | Confirmado |
| Reservaciones generan cargo inmediatamente       | Confirmado |
| Reservaciones gratuitas generan cargo de $0      | Confirmado |
| Cargos recurrentes se generan manualmente        | Confirmado |
| Generación de cargos es idempotente              | Confirmado |
| Se soportan cargos condonados                    | Confirmado |
| Cargos condonados tienen `Waived`                | Confirmado |
| Se conserva `OriginalAmount`                     | Confirmado |
| No se implementa todavía una entidad `Promotion` | Confirmado |

---

# 33. Pendientes de definición

Quedan pendientes, entre otros:

1. Día exacto de vencimiento.
2. Si existe periodo de tolerancia.
3. Recargos por vencimiento.
4. Reglas para cancelar cargos.
5. Reglas para modificar/cancelar reservaciones.
6. Métodos de pago.
7. Datos obligatorios de un pago.
8. Cómo se seleccionan los cargos que liquida un pago anticipado.
9. Reglas exactas de las promociones de pago anticipado.
10. Si un cargo de $0 tendrá estado `Paid` o un estado específico.
11. Reglas para generación de cargos extraordinarios.
12. Historial de propietarios.
13. Usuarios y permisos administrativos.
14. Respaldos de la base de datos local.
15. Reglas detalladas de disponibilidad de amenidades.

---

# 34. Próximo paso

El siguiente paso recomendado es definir formalmente los **Aggregates, Entities, Value Objects, Domain Services y Domain Events**, incluyendo las invariantes que cada Aggregate debe proteger.

Una vez cerrado ese diseño, se podrá traducir el modelo de dominio a:

```text
Domain
Application
Infrastructure
API
Blazor UI
```

y posteriormente diseñar el esquema PostgreSQL a partir del dominio validado.
