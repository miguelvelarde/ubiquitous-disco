# Domain Implementation Specification

**Version:** 0.2  
**Status:** Draft for implementation review  
**Date:** 2026-08-17

---

# 1. Purpose

This document defines how the approved domain model is to be implemented in C#.

It is an implementation guide, not a replacement for `DOMAIN-MODEL.md`.

`DOMAIN-MODEL.md` is the authoritative source for business rules. This document defines how those rules should be represented in code.

The implementation must not introduce business behavior, aggregates, value objects, abstractions, or patterns that are not justified by the approved domain model.

---

# 2. Source Documents

The implementation must be based on:

1. `DOMAIN-MODEL.md`
2. `DATABASE-DESIGN.md`
3. PostgreSQL DDL specification
4. This document

If a conflict exists, the approved domain rules in `DOMAIN-MODEL.md` take precedence.

The C# implementation must not invent missing business rules.

---

# 3. Domain Implementation Principles

## 3.1 Pragmatic DDD

DDD is applied pragmatically.

Do not introduce a pattern merely because it is commonly associated with DDD.

Do not introduce:

- Additional aggregates.
- Value objects without domain behavior.
- Domain events without a concrete requirement.
- Generic abstractions.
- Generic base entities.
- Generic repositories inside the domain.

Prefer explicit and simple domain code.

---

## 3.2 Encapsulation

Domain state must not be freely mutable from outside the entity.

Business state transitions must be expressed through domain behavior.

Prefer:

```csharp
charge.Pay(...);
charge.Waive();
charge.Cancel();
```

over directly assigning lifecycle state.

---

## 3.3 Domain independence

The Domain layer must not depend on:

- PostgreSQL.
- Entity Framework Core.
- `DbContext`.
- SQL.
- Stored procedures.
- Repository implementations.
- HTTP.
- UI.
- Authentication infrastructure.

Domain objects must be usable without a database.

---

## 3.4 Application coordination

The Application layer coordinates operations involving multiple aggregates or external state.

Examples:

- Confirm Reservation + Charge.
- Cancel Reservation + ChargeAdjustment.
- Change Owner + DepartmentOwnerHistory.
- Generate recurring Charges.
- Register Payment.

The application layer must not bypass aggregate invariants.

---

# 4. Domain Types and Classification

The implementation must use the following classification.

| Type | C# representation | Classification |
|---|---|---|
| Charge | `class` | Aggregate Root |
| Payment | `class` | Entity inside Charge Aggregate |
| Reservation | `class` | Aggregate Root |
| Department | `class` | Entity |
| Owner | `class` | Entity |
| DepartmentOwnerHistory | `class` | Entity |
| ServiceCatalog | `class` | Entity |
| RecurringService | `class` | Entity |
| Amenity | `class` | Entity |
| User | `class` | Entity |
| ChargeAdjustment | `class` | Entity |
| ChargeOrigin | `class` / immutable type | Value Object |
| ChargeStatus | `enum` | Domain type |
| PaymentMethod | `enum` | Domain type |
| BillingPeriod | `int` | Primitive domain representation |
| Money | `decimal` | Primitive domain representation |

`Money`, `BillingPeriod`, and `PaymentMethod` must not be implemented as Value Objects in this version.

---

# 5. Entities

Only domain-relevant properties and behavior should be exposed publicly.

Exact property names must remain consistent with the database design unless there is a documented domain reason to differ.

## 5.1 Charge

`Charge` is the Aggregate Root of the Charge Aggregate.

The aggregate contains:

```text
Charge
└── Payment*
```

`Payment` is an entity owned by the Charge Aggregate.

### Required domain state

Charge must represent at least:

- Id.
- Department.
- OriginalAmount.
- Amount.
- BillingPeriod when applicable.
- DueDate.
- Origin.
- Status.
- Payment when present.
- Creation information.

### Amount rules

`OriginalAmount` is immutable after creation.

`Amount` can only change through explicit domain behavior.

A negative Charge amount is not allowed.

A zero-amount Charge is immediately considered `Waived`.

### Status

```csharp
Pending
Paid
Waived
Cancelled
```

Valid transitions:

```text
Pending -> Paid
Pending -> Waived
Pending -> Cancelled
```

`Paid`, `Waived`, and `Cancelled` are terminal.

No other transitions are valid.

### Behavior

Charge must expose behavior for:

```csharp
Pay(...)
Waive()
Cancel()
```

#### Pay

Rules:

- Charge must be `Pending`.
- Payment must equal the current `Amount`.
- Partial payment is forbidden.
- A second payment is forbidden.
- The resulting Charge status is `Paid`.
- A Payment entity is created as part of the Charge Aggregate.

#### Waive

Rules:

- Charge must be `Pending`.
- `OriginalAmount` does not change.
- `Amount` becomes `0`.
- Status becomes `Waived`.
- No Payment is created.

#### Cancel

Rules:

- Charge must be `Pending`.
- Status becomes `Cancelled`.
- Historical Charge data remains intact.
- A paid Charge is not changed to `Cancelled`.
- Economic reversal of a paid Charge is represented through a new `ChargeAdjustment`.

---

# 6. Payment

`Payment` is an Entity inside the Charge Aggregate.

It must not be implemented as an independent Aggregate Root.

Required fields:

- Id.
- ChargeId.
- PaymentDate.
- Amount.
- PaymentMethod.
- Reference.
- Notes.
- CreatedAt.
- CreatedBy.

All are mandatory according to the domain model.

### Payment methods

```csharp
Cash
Card
Transfer
Other
```

`Reference` is administrator-provided free text.

`Payment.Amount` must correspond to the current Charge amount when the payment is registered.

A Charge cannot contain multiple payments.

The implementation must prevent creation of a Payment that violates Charge invariants.

---

# 7. Reservation

`Reservation` is an Aggregate Root.

Its lifecycle is:

```text
Confirmed -> Cancelled
```

There is no practical `Pending` state.

### Confirmation

Confirmation must result in a valid Reservation.

When a Charge is created as part of confirmation:

- Reservation and Charge are independent aggregates.
- Charge receives the amount as input.
- Charge does not calculate the reservation amount.
- Charge does not query Reservation, Amenity, ServiceCatalog, or other entities.
- Confirmation and Charge creation are one application transaction.

The amount may have been calculated by the application layer or by the persistence operation according to the selected implementation.

### Cancellation

A Reservation can be cancelled at any time.

Cancellation does not delete the Reservation.

If economic compensation/reversal is required, a new `ChargeAdjustment` is created.

The original Charge and Payment remain unchanged.

---

# 8. Reservation Availability

Availability is not an invariant that `Reservation` can validate independently.

A new Reservation cannot overlap an existing Reservation.

Maintenance is represented by a Reservation using a maintenance `ServiceCatalog` entry.

Therefore the same overlap rule applies to:

- Ordinary reservations.
- Maintenance reservations.

The first existing record has priority.

Availability validation must be coordinated by the Application/Persistence layers.

`Reservation` must not inject or call a repository to check availability.

---

# 9. ChargeOrigin

`ChargeOrigin` is a Value Object.

Initial origin types:

```text
RecurringService
Reservation
Extraordinary
```

The origin determines which source reference is valid.

The implementation must preserve the consistency between:

- Origin type.
- Origin reference.

Examples:

```text
RecurringService -> RecurringService reference
Reservation      -> Reservation reference
Extraordinary    -> no recurring/reservation origin
```

The exact persistence representation must remain consistent with the DDL.

`ChargeOrigin` must be immutable.

It must provide value-based equality.

---

# 10. ChargeAdjustment

`ChargeAdjustment` is an independent accounting record.

It compensates or modifies the economic effect of an existing Charge without modifying the historical Charge itself.

Example:

```text
Charge           +1000
Payment          +1000
ChargeAdjustment -1000
```

Negative amounts are valid for compensation.

The administrator determines:

- Concept.
- Amount.
- When the adjustment is appropriate.

There is no mandatory reason catalog or automatic applicability rule in this version.

ChargeAdjustment may support:

- Reservation reversals.
- Bonuses.
- Other discretionary adjustments.

---

# 11. RecurringService

`RecurringService` represents that a Department receives a ServiceCatalog service on a recurring basis.

It is not an Aggregate Root.

Its `StartDate` belongs to the service relationship.

Recurring charge generation must:

- Use the applicable ServiceCatalog amount.
- Generate a full billing month.
- Never prorate.
- Use `BillingPeriod` in `YYYYMM` format.
- Prevent duplicate Charges for the same `RecurringService + BillingPeriod`.

Stopping future charges does not require a historical active/inactive timeline.

If a recurring service is no longer used for future generation, it simply stops participating in future charge generation.

---

# 12. ServiceCatalog

`ServiceCatalog` represents a chargeable service/concept.

It contains `DefaultAmount`.

It may represent:

- Recurring services.
- Amenity/service charges.
- Extraordinary charges.
- Optional administrator-defined services such as surcharges.

`DefaultAmount` cannot be negative.

Tariff changes affect only future Charges.

Existing Charges must never be recalculated because the catalog amount changed.

Tariff-change history is out of scope.

---

# 13. BillingPeriod

`BillingPeriod` is represented as an `int`.

Format:

```text
YYYYMM
```

Examples:

```text
202608
202701
```

The implementation must validate that the value represents a valid year and month.

It must not contain a day component.

No `DateTime`, `DateOnly`, or Value Object is required for `BillingPeriod` in this version.

If helper methods are required, they must not turn `BillingPeriod` into a separate domain abstraction without a concrete requirement.

---

# 14. ChargeStatus

`ChargeStatus` should be represented as an enum.

```csharp
public enum ChargeStatus
{
    Pending,
    Paid,
    Waived,
    Cancelled
}
```

Enum values must not be used to infer lifecycle transitions automatically.

The `Charge` entity is responsible for enforcing valid transitions.

---

# 15. PaymentMethod

`PaymentMethod` should be represented as an enum.

```csharp
public enum PaymentMethod
{
    Cash,
    Card,
    Transfer,
    Other
}
```

It is not a Value Object in this version.

---

# 16. Money

Money is represented using:

```csharp
decimal
```

The domain must not use:

- `double`.
- `float`.

Amounts must not be negative unless the specific domain record explicitly permits it.

`ChargeAdjustment` is the known exception because negative adjustments are explicitly supported.

---

# 17. Validation Responsibility

## 17.1 Domain

The Domain layer validates rules that can be determined from the entity or aggregate itself.

Examples:

- Charge lifecycle transitions.
- Payment amount matching Charge amount.
- No partial payments.
- No duplicate payment.
- Charge amount rules.
- ChargeOrigin validity.
- BillingPeriod validity.
- Required state for domain behavior.

---

## 17.2 Application

The Application layer coordinates rules requiring other aggregates or external state.

Examples:

- Reservation availability.
- Maintenance conflicts.
- Reservation + Charge.
- Reservation cancellation + ChargeAdjustment.
- Owner change + ownership history.
- Recurring Charge generation.
- Registering a Payment.

---

## 17.3 Persistence / Database

Persistence is responsible for database integrity guarantees.

Examples:

- Primary keys.
- Foreign keys.
- Unique constraints.
- Check constraints.
- Required columns.
- Numeric precision.
- One Payment per Charge.
- Recurring Charge idempotency.

Database constraints complement domain validation.

---

# 18. C# Conventions

## 18.1 IDs

Entity IDs use:

```csharp
Guid
```

IDs are immutable after entity creation.

---

## 18.2 Nullability

Nullable reference types must be enabled.

Required domain properties should not be nullable.

Do not use the null-forgiving operator merely to suppress compiler warnings.

---

## 18.3 Constructors

Constructors must establish required state.

Prefer constructors with required parameters.

Do not expose unrestricted public constructors if they allow creation of invalid domain objects.

A persistence-required constructor may exist with restricted accessibility when necessary.

---

## 18.4 Setters

Avoid public setters for domain state.

Prefer:

```csharp
public ChargeStatus Status { get; private set; }
```

and explicit behavior:

```csharp
charge.Pay(...);
charge.Waive();
charge.Cancel();
```

---

## 18.5 Collections

Aggregate-owned collections must not be exposed as mutable collections.

Prefer:

```csharp
private readonly List<Payment> _payments = [];

public IReadOnlyCollection<Payment> Payments => _payments;
```

When appropriate, modifications must be performed through aggregate behavior.

---

## 18.6 Dates

Use the type that represents the domain meaning:

- `DateOnly` for date-only values.
- `DateTime` or `DateTimeOffset` only when time information is meaningful.

`BillingPeriod` remains an `int`.

---

# 19. Explicitly Forbidden Patterns

The following are not permitted without a new architectural decision.

## 19.1 Repository access from entities

```csharp
public class Reservation
{
    // Forbidden:
    // IRepository<Reservation> repository;
}
```

Entities must not query repositories.

---

## 19.2 DbContext inside domain

Domain entities must not depend on Entity Framework Core or `DbContext`.

---

## 19.3 SQL inside domain

No SQL, stored procedure calls, or database commands belong in the Domain layer.

---

## 19.4 Arbitrary public mutation

Do not expose unrestricted setters for business state.

---

## 19.5 Partial payments

Do not implement partial payment behavior.

---

## 19.6 Mutable financial history

Do not modify historical Charges to represent later financial events.

Use `ChargeAdjustment` when an economic correction is required.

---

## 19.7 Automatic overdue state

Do not add:

```text
Overdue
```

to `ChargeStatus`.

Overdue is determined from `DueDate`.

---

## 19.8 Automatic overdue surcharge

Do not implement an automatic overdue surcharge rule.

If the administrator needs a surcharge, it is handled as a discretionary service/charge according to the approved domain rules.

---

## 19.9 Automatic proration

Do not prorate recurring Charges.

---

## 19.10 Unnecessary DDD abstractions

Do not introduce:

- Generic aggregate base classes.
- Generic entity base classes without a concrete need.
- Domain events without a requirement.
- Value Objects without domain behavior.
- Specification patterns without a concrete use case.
- Domain services merely to move code out of entities.

---

# 20. Implementation Order

Implementation should proceed incrementally.

## Phase 1 — Domain types

Implement:

1. `ChargeStatus`.
2. `PaymentMethod`.
3. `ChargeOrigin`.
4. Billing period validation/helpers using `int`.

---

## Phase 2 — Charge Aggregate

Implement:

1. `Charge`.
2. `Payment`.
3. Charge creation rules.
4. `Pay()`.
5. `Waive()`.
6. `Cancel()`.

Then create unit tests for all valid and invalid state transitions.

---

## Phase 3 — ChargeAdjustment

Implement `ChargeAdjustment` and its accounting rules.

---

## Phase 4 — Reservation Aggregate

Implement:

1. `Reservation`.
2. Confirmation.
3. Cancellation.
4. Application coordination with Charge.

---

## Phase 5 — Supporting entities

Implement:

1. `Department`.
2. `Owner`.
3. `DepartmentOwnerHistory`.
4. `ServiceCatalog`.
5. `RecurringService`.
6. `Amenity`.
7. `User`.

---

## Phase 6 — Application coordination

Implement use cases for:

- Register Payment.
- Confirm Reservation.
- Cancel Reservation.
- Generate recurring Charges.
- Change Owner.
- Create ChargeAdjustment.

---

## Phase 7 — Persistence

Implement PostgreSQL persistence according to the approved DDL and database design.

Persistence must conform to the domain model rather than changing domain behavior to match database convenience.

---

## Phase 8 — Integration

Connect:

- Domain.
- Application.
- Persistence.
- Authorization.

Server-side authorization must enforce:

```text
Admin     -> Commands + Queries
ReadOnly  -> Queries only
```

---

# 21. Implementation Rule for AI-Assisted Development

When generating or modifying domain code, AI-assisted tools must follow these rules:

1. Treat `DOMAIN-MODEL.md` as the authoritative business specification.
2. Treat this document as the C# implementation specification.
3. Do not invent missing business rules.
4. Do not introduce new aggregates without explicit approval.
5. Do not introduce new Value Objects without explicit approval.
6. Do not add persistence dependencies to the Domain layer.
7. Do not add partial-payment behavior.
8. Do not add an `Overdue` Charge state.
9. Do not add automatic overdue surcharges.
10. Do not add automatic proration.
11. Do not modify historical Charges to represent later financial events.
12. Prefer explicit domain behavior over direct state mutation.
13. When a requirement is ambiguous or missing, stop and request clarification rather than guessing.

---

# End of Document