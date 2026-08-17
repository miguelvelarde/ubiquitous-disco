# Domain Model — Condominium Administration System

**Version:** 1.0  
**Status:** Final baseline for implementation  
**Date:** 2026-08-16

## 1. Purpose

System for condominium administration: recurring maintenance charges, additional services, amenity reservations, payments, owners and account statements.

Scope: monolithic application, PostgreSQL, one active user at a time, roles `Admin` and `ReadOnly`, no distributed processing, and no required background service for recurring charges.

## 2. Bounded Contexts

### Property Management
Department, Owner, DepartmentOwnerHistory, CondominiumSettings.

### Billing
ServiceCatalog, RecurringService, Charge, Payment, ChargeAdjustment.

### Amenities
Amenity, Reservation. Maintenance periods are Reservations using a maintenance ServiceCatalog entry.

## 3. Aggregates

### Charge Aggregate

```text
Charge
└── Payment*
```

`Charge` is the Aggregate Root. `Payment` is an Entity inside the aggregate. Charge protects its state, applies payment/waiver, and prevents partial or duplicate payments.

### Reservation Aggregate

`Reservation` is an Aggregate Root. Reservation and Charge are independent Aggregates. Charge may reference its originating Reservation but does not contain it.

## 4. Non-Aggregate Entities

Department, Owner, ServiceCatalog, RecurringService, Amenity and DepartmentOwnerHistory are not Aggregate Roots.

## 5. Value Objects

### ChargeOrigin

Initial types: `RecurringService`, `Reservation`, `Extraordinary`. The origin determines which reference is valid.

Money, BillingPeriod and PaymentMethod are intentionally not Value Objects: they have no current independent domain behavior. `BillingPeriod` is persisted as integer `YYYYMM`.

## 6. Charge

### States

```text
Pending
  ├── Paid
  ├── Waived
  └── Cancelled
```

`Paid`, `Waived` and `Cancelled` are terminal. No partial payments.

### Amounts

`OriginalAmount` is immutable. `Amount` changes only through explicit domain behavior. A zero-amount Charge is considered `Waived`.

### Charge.Pay()

Charge must be `Pending`; payment must equal the current amount; partial payments are forbidden; a Charge can only be paid once.

### Charge.Waive()

Charge must be `Pending`; `OriginalAmount` remains unchanged; `Amount` becomes zero; status becomes `Waived`; no Payment is created.

### Charge.Cancel()

Administrative cancellation is allowed from `Pending` and results in terminal `Cancelled`. A paid Charge is not changed to cancelled; an economic reversal is represented by a new `ChargeAdjustment`.

## 7. Payment

Payment belongs to Charge Aggregate. Fields: Id, ChargeId, PaymentDate, Amount, PaymentMethod, Reference, Notes, CreatedAt, CreatedBy. All are mandatory.

Methods: `Cash`, `Card`, `Transfer`, `Other`.

`Reference` is free text chosen by the administrator to identify the payment.

## 8. ChargeAdjustment

A new accounting record used to compensate or modify the economic effect of an existing Charge without changing the original historical record.

Example:

```text
Charge           +1000
Payment          +1000
ChargeAdjustment -1000
```

Negative amounts are allowed for compensation. There is no mandatory reason catalog or automatic rule for applicability; the administrator decides the concept, amount and when to use it. It may support reservation reversals, bonuses and other discretionary adjustments.

## 9. Reservation

There is no practical `Pending` state. Initial lifecycle:

```text
Confirmed -> Cancelled
```

Confirmation and Charge creation happen in one transaction. The Charge amount is supplied as an input; Charge does not calculate it or query other entities. The UI/application may obtain it beforehand, or the Stored Procedure may obtain it internally.

## 10. Reservation Availability

A Reservation cannot overlap another Reservation. Maintenance is represented by a Reservation with a maintenance ServiceCatalog entry, so the same overlap rule blocks both ordinary reservations and maintenance. The first existing record has priority. Cross-record availability validation belongs in application/persistence coordination, not in the Reservation entity querying repositories.

## 11. Reservation Cancellation

A Reservation can be cancelled at any time. It is not deleted. A `ChargeAdjustment` is created when economic compensation/reversal is required. Original Charge and Payment remain unchanged.

## 12. Recurring Services

`RecurringService` represents that a Department receives a catalog service on a recurring basis and is not an Aggregate Root. Its StartDate is associated with the service relationship. No active/inactive historical timeline is required; if charging should stop, the recurring service is no longer used for future generation. Payment history is the relevant historical record.

## 13. Service Catalog

`ServiceCatalog` contains chargeable concepts, including recurring services, amenity/service charges, extraordinary charges, and optional service types such as a surcharge if the administrator chooses to create one. It contains `DefaultAmount`.

Tariff changes affect only future Charges. Existing Charges are never recalculated. Tariff-change history is out of scope.

## 14. Billing Period

`BillingPeriod` uses `YYYYMM`, e.g. `202608`.

If `StartDate = 2026-08-15` and `BillingPeriod = 202608`, the full August Charge is generated. There is no proration.

## 15. Due Date

`DueDate` is historical Charge data. The due day is configured through condominium settings.

A Charge becomes overdue immediately after its due date. `Overdue` is not a persisted Charge state and there is no automatic overdue surcharge rule.

## 16. Recurring Charge Generation

Recurring charge generation is an explicit application/domain operation, not a required background process. It must be idempotent; at most one recurring Charge may exist for `RecurringService + BillingPeriod`. Database uniqueness is the final integrity guarantee.

## 17. Owners and Departments

Department is not an Aggregate Root. Changing owner does not modify historical Charges or Payments. Owner changes are recorded in `DepartmentOwnerHistory`. The current history record may have `EndDate = NULL`, meaning the ownership period remains active.

## 18. Users and Permissions

Two roles only:

- **Admin:** Commands + Queries.
- **ReadOnly:** Queries only.

ReadOnly cannot create, modify, cancel, pay, waive, generate charges, change owners, create/cancel reservations, or otherwise change persistent state. Authorization is enforced server-side, not only by the UI.

## 19. Auditability

No generic AuditLog, `updated_by`, `updated_at`, snapshots or generic field-change history.

Where creator identification is relevant, records use:

```text
created_at
created_by
```

`created_by` identifies the authenticated user who created the record. For later modifications, knowing the original creator is sufficient for this version unless a new requirement says otherwise. New business records such as Payment, ChargeAdjustment and DepartmentOwnerHistory identify their creator.

## 20. Application Coordination

The Application Layer coordinates multi-Aggregate operations such as Confirm Reservation + Charge, Cancel Reservation + ChargeAdjustment, Change Owner + owner history, Generate recurring Charges, and Register Payment. A transaction commits only when the complete use case succeeds.

## 21. Discretionary Operations

No automatic rules are implemented for overdue surcharges, ChargeAdjustment reasons/applicability, extraordinary charges, promotions, or administrative Charge cancellation. These are deliberately discretionary administrator operations.

## 22. Financial History

Historical financial records are not modified to hide later events. Corrections/reversals are represented by new records, especially `ChargeAdjustment`.

## 23. Out of Scope

Automatic overdue surcharge rules; future payment methods; promotion engine; tariff history; generic audit log; distributed processing; background recurring-charge processing; partial payments; automatic proration; complex role/permission matrices.

## 24. Design Philosophy

DDD is used pragmatically. Do not introduce Aggregates, Value Objects, Domain Events or abstractions solely to follow patterns. Priorities are clear business rules, strong consistency where needed, simplicity, financial traceability and maintainability.
