# Domain Implementation Specification

**Version:** 0.3
**Status:** Implementation baseline
**Date:** 2026-08-20

---

# 1. Purpose

This document defines how the approved domain model is implemented in C#.

`DOMAIN-MODEL.md` is the authority for business rules. This document defines their C# representation and implementation constraints.

The implementation must favor simplicity and pragmatic DDD. Do not introduce abstractions, entities, Value Objects, Aggregates, or Domain Events without a concrete domain requirement.

---

# 2. Source Documents

Implementation must be based on:

1. `DOMAIN-MODEL.md`
2. `DATABASE-DESIGN.md`
3. PostgreSQL DDL
4. This document

If a conflict exists, the latest approved domain decision takes precedence and the affected documentation must be updated.

AI-assisted development must not invent missing business rules.

---

# 3. Domain Implementation Principles

## 3.1 Pragmatic DDD

Use DDD only where it provides concrete value.

Do not introduce patterns solely for architectural purity.

Prefer:

* Simple entities.
* Explicit domain behavior.
* Clear invariants.
* Simple C# types.
* Application coordination for cross-entity operations.

---

## 3.2 Encapsulation

Domain state must not be freely mutable.

Business transitions must use explicit methods.

For example:

```csharp
charge.Pay(...);
charge.Waive();
charge.Cancel();
```

instead of:

```csharp
charge.Status = ChargeStatus.Paid;
```

---

## 3.3 Domain independence

The Domain layer must not depend on:

* PostgreSQL.
* Entity Framework Core.
* `DbContext`.
* SQL.
* Stored procedures.
* Repository implementations.
* HTTP.
* UI.

Domain behavior must be testable without a database.

---

## 3.4 Application coordination

Operations requiring multiple entities, persistence queries, or transactions are coordinated by the Application layer.

Examples:

* Register Payment.
* Generate recurring Charges.
* Create Reservation.
* Cancel Reservation.
* Change Owner.
* Create an Adjustment Charge.

Domain entities must not query repositories.

---

# 4. Domain Types and Classification

| Type                   | C# representation | Classification                  |
| ---------------------- | ----------------- | ------------------------------- |
| Charge                 | `class`           | Aggregate Root                  |
| Payment                | `class`           | Entity inside Charge Aggregate  |
| Reservation            | `class`           | Aggregate Root                  |
| Department             | `class`           | Entity                          |
| Owner                  | `class`           | Entity                          |
| DepartmentOwnerHistory | `class`           | Entity                          |
| Service                | `class`           | Entity                          |
| DepartmentService      | relationship      | Association                     |
| User                   | `class`           | Entity                          |
| ChargeStatus           | `enum`            | Domain enum                     |
| PaymentMethod          | `enum`            | Domain enum                     |
| ServiceType            | `enum`            | Domain enum                     |
| BillingPeriod          | `int`             | Primitive domain representation |
| Money                  | `decimal`         | Primitive domain representation |

There is no `ChargeOrigin` Value Object in the current model.

There are no separate domain entities for:

* `RecurringService`
* `Amenity`
* `ChargeAdjustment`

---

# 5. Service

`Service` represents a concept that may be charged, associated with a Department, reserved, or used for accounting adjustments.

It replaces the previous `ServiceCatalog` concept.

A Service contains domain information including:

* Id.
* Name.
* Description.
* Type.
* DefaultAmount.
* IsReservable.
* Active state where applicable.

## 5.1 ServiceType

`ServiceType` is represented as:

```csharp
public enum ServiceType
{
    Recurring,
    Event,
    Extraordinary,
    Adjustment
}
```

### Recurring

A recurring Service may be associated permanently with Departments through `DepartmentService`.

Those associations are used to generate recurring Charges.

### Event

Represents an event-related or individually used service.

It may also be reservable when `IsReservable` is true.

### Extraordinary

Represents a discretionary non-recurring charge concept.

### Adjustment

Represents an accounting adjustment.

An Adjustment does not have a separate entity or table.

It is represented by a normal `Charge` referencing a Service whose type is `Adjustment`.

Adjustment Charges may have negative amounts.

---

## 5.2 DefaultAmount

Money is represented as:

```csharp
decimal
```

`Service.DefaultAmount` is the current amount associated with the Service.

For normal Services, the amount cannot be negative.

An Adjustment Service may result in a negative Charge amount.

Changing `DefaultAmount` affects only Charges created after the change.

Historical Charges must never be recalculated.

---

## 5.3 Reservable Services

`Service.IsReservable` determines whether the Service can be used in a Reservation.

Examples:

```text
Maintenance payment     -> IsReservable = false
Use of swimming pool    -> IsReservable = true
Use of clubhouse        -> IsReservable = true
Accounting adjustment   -> IsReservable = false
```

Reservation availability is determined using the reservable Service identity.

---

# 6. DepartmentService

`DepartmentService` represents the current association between a Department and a Service.

Conceptually:

```text
Department <-> Service
```

It exists only to identify which Services a Department currently receives.

Its persistence identity is the composite key:

```text
DepartmentId + ServiceId
```

It does not require:

* Independent Id.
* Amount.
* CreatedAt.
* CreatedBy.
* StartDate.
* EndDate.
* IsActive.
* Historical tracking.

The Service amount remains in `Service.DefaultAmount`.

Removing a `DepartmentService` association means the Department no longer receives that Service for future operations.

Historical Charges remain unchanged.

For recurring Services, `DepartmentService` is the source used to determine which Departments receive recurring Charges.

---

# 7. Charge Aggregate

The Charge Aggregate is:

```text
Charge
└── Payment*
```

`Charge` is the Aggregate Root.

`Payment` is an Entity inside the Aggregate.

`Charge` references:

* DepartmentId.
* ServiceId.

Charge does not contain or reference:

* Reservation.
* RecurringService.
* ChargeOrigin.
* ChargeAdjustment.

The Service associated with the Charge provides the business concept represented by that Charge.

---

# 8. Charge

A Charge represents a financial movement associated with a Department and Service.

Required domain state includes:

* Id.
* DepartmentId.
* ServiceId.
* BillingPeriod.
* OriginalAmount.
* Amount.
* DueDate.
* Status.
* Payment when present.
* Creation information.

## 8.1 Amounts

Money uses:

```csharp
decimal
```

`OriginalAmount` is immutable after creation.

`Amount` changes only through explicit domain behavior.

For normal Charges:

```text
Amount >= 0
```

Adjustment Charges may have negative amounts.

A normal zero-amount Charge is considered `Waived`.

---

## 8.2 ChargeStatus

```csharp
public enum ChargeStatus
{
    Pending,
    Paid,
    Waived,
    Cancelled
}
```

For normal Charges:

```text
Pending
  ├── Paid
  ├── Waived
  └── Cancelled
```

`Paid`, `Waived`, and `Cancelled` are terminal.

No partial payments are supported.

Adjustment Charges are created directly as `Paid`.

They do not transition through `Pending`.

---

## 8.3 Charge.Pay()

`Pay()` applies only to a normal pending Charge.

Rules:

* Charge must be `Pending`.
* Payment amount must equal the current Charge amount.
* Partial payments are forbidden.
* A Charge cannot be paid more than once.
* A Payment entity is created within the Charge Aggregate.
* Charge status becomes `Paid`.

Adjustment Charges created directly as `Paid` do not require a Payment.

---

## 8.4 Charge.Waive()

Rules:

* Charge must be `Pending`.
* `OriginalAmount` remains unchanged.
* `Amount` becomes zero.
* Status becomes `Waived`.
* No Payment is created.

---

## 8.5 Charge.Cancel()

Administrative cancellation is allowed from `Pending`.

The resulting state is:

```text
Cancelled
```

A cancelled Charge is not deleted.

A paid Charge is not changed to `Cancelled`.

If an economic correction is required after payment, a new Adjustment Charge is created instead of modifying the historical Charge.

---

# 9. Adjustment Charges

There is no `ChargeAdjustment` entity.

An accounting adjustment is represented as:

```text
Service.Type = Adjustment
        +
Charge
```

Examples:

```text
Maintenance Charge       +1000
Payment                   +1000
Adjustment Charge         -1000
```

Adjustment rules:

* Amount may be positive or negative.
* The administrator decides when to create it.
* There is no mandatory reason catalog.
* There are no automatic applicability rules.
* It may represent refunds, compensation, bonuses, or other discretionary adjustments.
* It is created directly with `Paid` status.
* It does not require a Payment.
* `BillingPeriod` is mandatory.
* The default BillingPeriod is the current billing period.

The original Charge and Payment remain unchanged.

---

# 10. Payment

`Payment` is an Entity inside the Charge Aggregate.

It is not an independent Aggregate Root.

Required fields:

* Id.
* ChargeId.
* PaymentDate.
* Amount.
* PaymentMethod.
* Reference.
* Notes.
* CreatedAt.
* CreatedBy.

The payment settles one complete Charge.

Partial payments are not supported.

A Charge can have at most one Payment.

---

## 10.1 PaymentMethod

```csharp
public enum PaymentMethod
{
    Cash,
    Card,
    Transfer,
    Other
}
```

`PaymentMethod` is not a Value Object.

---

# 11. BillingPeriod

`BillingPeriod` is represented as:

```csharp
int
```

using:

```text
YYYYMM
```

Examples:

```text
202608
202701
```

It is not a Value Object.

BillingPeriod must represent a valid year and month.

It is mandatory for every Charge.

When no period is explicitly supplied, the current billing period is used.

No day component exists.

BillingPeriod must not be represented as `DateTime` or `DateOnly`.

Helper/validation logic may operate on the integer without introducing a `BillingPeriod` Value Object.

---

# 12. Recurring Charge Generation

There is no `RecurringService` entity.

Recurring generation uses:

```text
DepartmentService
        +
Service.Type = Recurring
        ↓
Charge
```

For each applicable association:

1. Read the associated Service.
2. Use `Service.DefaultAmount`.
3. Create the Charge for the requested BillingPeriod.
4. Preserve the amount in the created Charge.

There is no proration.

Changing `Service.DefaultAmount` affects only future Charges.

Removing a row from `DepartmentService` prevents that Service from participating in future recurring generation for that Department.

Recurring generation must be idempotent.

At most one recurring Charge should be generated for the same:

```text
Department + Service + BillingPeriod
```

The implementation must preserve this rule without preventing legitimate multiple non-recurring Charges for the same Department, Service, and BillingPeriod.

The final integrity strategy may therefore be implemented by the recurring-generation persistence operation rather than a global unique constraint over all Charges.

---

# 13. Reservation Aggregate

`Reservation` is an Aggregate Root independent from Billing.

There is no `Amenity` entity.

Reservation references:

* DepartmentId.
* ServiceId.

The referenced Service represents the reservable resource.

The Service must have:

```text
IsReservable = true
```

Reservation does not reference:

* Charge.
* Payment.
* Amenity.

Billing and reservations remain separate concerns.

---

## 13.1 Reservation lifecycle

The lifecycle is:

```text
Confirmed -> Cancelled
```

There is no practical `Pending` state.

A Reservation is initially created as `Confirmed`.

Cancellation does not delete the historical Reservation.

---

## 13.2 Administrative reservations

Every Reservation has a DepartmentId.

Administrative blocks such as:

* Maintenance.
* Repairs.
* Administrative use.
* Other temporary blocks.

use the default Department reserved for condominium administration.

`DepartmentId` is therefore not nullable.

No special Maintenance entity or reservation type is required.

Notes may be used to describe the administrative reason.

---

# 14. Reservation Availability

A Reservation cannot overlap another active Reservation for the same Service.

The conflict rule is:

```text
same ServiceId
+
overlapping date/time period
+
existing Reservation is not Cancelled
```

The same rule applies to:

* Resident reservations.
* Administrative reservations.
* Maintenance blocks.

This validation requires information about other Reservations and therefore does not belong inside the Reservation entity querying a repository.

The Application/Persistence layers coordinate availability validation.

---

# 15. Department, Owner and Ownership History

`Department` and `Owner` are Entities.

Changing ownership must not modify historical Charges or Payments.

Ownership changes are recorded through `DepartmentOwnerHistory`.

The current ownership record may have:

```text
EndDate = null
```

Historical ownership records must be preserved.

The system also contains a default Department representing condominium administration for operations that require a Department identity, including administrative Reservations.

---

# 16. Validation Responsibility

## 16.1 Domain

The Domain layer validates rules that can be determined from the entity or Aggregate itself.

Examples:

* Charge lifecycle.
* Payment amount.
* No partial payments.
* No duplicate Payment inside Charge.
* Charge amount rules.
* Adjustment Charge rules.
* BillingPeriod format.
* Reservation date range.
* Service amount rules.

---

## 16.2 Application

The Application layer coordinates rules requiring external state or multiple domain objects.

Examples:

* Confirming that a Service is reservable.
* Reservation overlap validation.
* Register Payment.
* Generate recurring Charges.
* Create Adjustment Charge.
* Change Owner.

---

## 16.3 Persistence / Database

Persistence provides final integrity guarantees where appropriate.

Examples:

* Primary keys.
* Foreign keys.
* Composite DepartmentService key.
* Unique Payment per Charge.
* Check constraints.
* Numeric precision.
* Reservation overlap protection.
* Recurring generation idempotency.

Database constraints complement domain validation.

---

# 17. C# Conventions

## 17.1 IDs

Entity identifiers use:

```csharp
Guid
```

IDs are immutable after creation.

`DepartmentService` does not have an independent Guid because its identity is:

```text
DepartmentId + ServiceId
```

---

## 17.2 Money

Money uses:

```csharp
decimal
```

Do not use:

```csharp
float
double
```

for monetary values.

---

## 17.3 Nullability

Nullable reference types must be enabled.

Required domain properties should not be nullable.

Do not use the null-forgiving operator merely to suppress initialization warnings.

---

## 17.4 Constructors

Constructors must establish valid required state.

Avoid constructors that allow invalid domain objects to be created.

Persistence-specific constructors may use restricted accessibility when required.

---

## 17.5 Setters

Business state must not expose unrestricted public setters.

Prefer:

```csharp
public ChargeStatus Status { get; private set; }
```

and explicit behavior.

---

## 17.6 Collections

Aggregate-owned collections must not expose unrestricted mutation.

For example:

```csharp
private readonly List<Payment> _payments = [];

public IReadOnlyCollection<Payment> Payments => _payments;
```

---

## 17.7 Dates

Use:

* `DateOnly` for date-only concepts.
* `DateTime` / `DateTimeOffset` where time is meaningful.

Reservation start/end values include time.

`BillingPeriod` remains an `int`.

---

# 18. Explicitly Forbidden Patterns

Do not introduce the following without a new approved design decision:

* `ChargeOrigin`.
* `RecurringService`.
* `Amenity`.
* `ChargeAdjustment` entity/table.
* Repository access from domain entities.
* `DbContext` inside the Domain layer.
* SQL or stored procedure calls inside domain entities.
* Public mutation of business state.
* Partial payments.
* Automatic proration.
* `Overdue` as a persisted Charge status.
* Automatic overdue surcharge rules.
* Generic Aggregate base classes without a concrete requirement.
* Generic Entity base classes without a concrete requirement.
* Domain Events without a requirement.
* Value Objects without independent domain behavior.
* A direct Reservation → Payment relationship.
* A required Reservation → Charge relationship.

Historical financial records must not be modified to hide later financial events.

---

# 19. Implementation Order

## Phase 1 — Domain enums and helpers

Implement:

1. `ChargeStatus`.
2. `PaymentMethod`.
3. `ServiceType`.
4. `int`-based BillingPeriod validation/helper logic.

`ChargeOrigin` must not be implemented.

---

## Phase 2 — Service model

Implement:

1. `Service`.
2. `DepartmentService`.

Validate:

* Service type.
* Default amount.
* Reservability.
* Department-Service association.

---

## Phase 3 — Charge Aggregate

Implement:

1. `Charge`.
2. `Payment`.
3. Normal Charge creation.
4. Adjustment Charge creation.
5. `Pay()`.
6. `Waive()`.
7. `Cancel()`.

Then implement unit tests for valid and invalid transitions.

---

## Phase 4 — Reservation Aggregate

Implement:

1. `Reservation`.
2. Confirmation-at-creation.
3. Cancellation.
4. Reservation date validation.

Availability checks remain outside the Aggregate because they require existing Reservation data.

---

## Phase 5 — Supporting entities

Implement:

1. `Department`.
2. `Owner`.
3. `DepartmentOwnerHistory`.
4. `User`.

---

## Phase 6 — Application coordination

Implement use cases for:

* Register Payment.
* Generate recurring Charges.
* Create Adjustment Charge.
* Create Reservation.
* Cancel Reservation.
* Change Owner.

---

## Phase 7 — Persistence

Implement PostgreSQL persistence according to the approved DDL.

Persistence must not change domain behavior merely for database convenience.

---

# 20. AI-Assisted Development Rules

When generating or modifying domain code:

1. Treat `DOMAIN-MODEL.md` as the business-rule authority.
2. Treat this document as the C# implementation specification.
3. Do not invent missing business rules.
4. Prefer the simplest implementation satisfying the documented requirements.
5. Do not introduce `ChargeOrigin`.
6. Do not introduce `RecurringService`.
7. Do not introduce `Amenity`.
8. Do not introduce a `ChargeAdjustment` entity.
9. Represent adjustments as Charges associated with an `Adjustment` Service.
10. Do not couple Reservation to Payment.
11. Do not require Reservation to reference Charge.
12. Do not introduce partial payments.
13. Do not introduce automatic proration.
14. Do not introduce an `Overdue` Charge state.
15. Do not add persistence dependencies to the Domain layer.
16. Do not introduce new Aggregates or Value Objects without explicit approval.
17. When a business decision is not specified, request clarification rather than guessing.

---

# End of Document
