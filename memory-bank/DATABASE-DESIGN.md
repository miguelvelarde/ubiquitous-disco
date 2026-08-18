# Database Design — Condominium Administration System

**Version:** 1.0  
**Status:** Final baseline for implementation  
**Date:** 2026-08-16

## 1. Purpose

PostgreSQL source of truth for tables, columns, keys, constraints, indexes, Stored Procedures and transaction boundaries.

All application tables, indexes and functions are created in the `cas` schema. Apply `DDL-Tables.sql`, then `CRUD-stored-procedures.sql`, then `BUSINESS-stored-procedures.sql`. Database callers should use qualified names such as `cas.charges` and `cas.register_payment`, or set `search_path` to `cas, public` for the connection.

## 2. General Rules

- PKs use UUID.
- Monetary amounts use `numeric(12,2)`.
- Normal Charge amounts cannot be negative.
- Adjustment Charges may have positive or negative amounts.
- State fields use `varchar` plus `CHECK` constraints.
- FKs enforce referential integrity.
- Historical financial records are not overwritten to hide later events.
- Business fields are `NOT NULL` unless there is an explicit domain reason for nullability.
- No generic AuditLog table.

## 3. Users

Minimum model:

```text
users
-----
id
username
password_hash
role
```

Roles: `Admin`, `ReadOnly`.

## 4. Audit Fields

Where creator auditing is relevant:

```text
created_at
created_by
```

Do not add `updated_at` or `updated_by`. No generic AuditLog or snapshots.

## 5. BillingPeriod

Persist as integer `YYYYMM`, e.g. `202608`. Database validation should ensure a valid year/month.

## 6. Charge

Must support Department, Amount, OriginalAmount, Status, DueDate, BillingPeriod, origin and origin references, plus creation audit.

Constraints:
- `OriginalAmount >= 0`.
- `Amount >= 0`.
- OriginalAmount is immutable after creation.
- Status values: `Pending`, `Paid`, `Waived`, `Cancelled`.

Origin consistency must be enforced:
- `RecurringService` -> RecurringServiceId required.
- `Reservation` -> ReservationId required.
- `Extraordinary` -> no unrelated origin reference.
- `Adjustment` -> no recurring/reservation origin reference; `OriginalAmount = 0`; amount is non-zero and may be positive or negative; status is `Paid` without a Payment.

## 7. Charge Uniqueness

Use a partial unique index to prevent duplicate recurring Charges for `RecurringServiceId + BillingPeriod` when the Charge has recurring-service origin.

## 8. Payment

Payment belongs to Charge. `Payment.ChargeId` is UNIQUE. Partial payments are unsupported. Payment amount must be positive.

Payment stores `created_at` and `created_by`.

Methods: `Cash`, `Card`, `Transfer`, `Other`. Reference is mandatory free text.

## 9. Adjustment Charges

An adjustment is a Charge with `source_type = 'Adjustment'`; there is no separate `charge_adjustments` table. It may have a positive or negative non-zero amount. Its `original_amount` is zero and it is created as `Paid` without a Payment. The ServiceCatalog entry defines its discretionary concept. Existing Charges and Payments are never modified to hide the adjustment.

## 10. Reservation

Must support Amenity, date/time range, status and creation audit. Cancellation does not delete the record.

## 11. Amenity Maintenance and Overlap

Maintenance/blocking periods are Reservations using a maintenance ServiceCatalog entry. Database integrity must prevent overlapping Reservations; this also prevents Reservation/Maintenance conflicts. The first existing record has priority.

The first existing record has priority.

## 12. Department Owner History

Owner changes are historical records. Close the previous ownership period and create the new one. Active ownership may have `EndDate = NULL`. Historical Charges and Payments are never modified.

## 13. Service Catalog

Contains chargeable concepts and `default_amount`. Tariff changes affect future Charges only. No tariff-change history. Extraordinary charges use ServiceCatalog concepts and the normal Charge flow.

## 14. Recurring Services

Links Department to ServiceCatalog. `StartDate` belongs to the recurring service relationship. No active/inactive historical timeline is required.

## 15. Stored Procedures

Expected procedures:

```text
generate_recurring_charges
confirm_reservation
cancel_reservation
register_payment
change_owner
```

Exact signatures, result shapes, locking and validation responsibilities are defined during implementation. Procedures may perform internal data lookups when that simplifies an atomic operation.

## 16. Transactional Operations

### Confirm Reservation

Validate availability + confirm Reservation + create Charge atomically.

### Cancel Reservation

Cancel Reservation + create an Adjustment Charge when required atomically.

### Register Payment

Validate Charge + create Payment + settle Charge atomically.

### Change Owner

Close previous ownership + assign new owner + create owner history atomically.

### Generate Recurring Charges

Must be idempotent and respect database uniqueness.

## 17. Database vs Domain Validation

Cross-record validations requiring queries belong in application/persistence coordination or Stored Procedures, not in Domain entities querying repositories. Examples: reservation availability, origin consistency, recurring-charge duplication, payment uniqueness and ownership changes. Database constraints remain the final integrity boundary.

## 18. Out of Scope

Generic audit logs, tariff history, automatic overdue surcharge calculation, promotion rules, future payment methods, partial payments and distributed coordination.

## 19. Implementation Sequence

1. Validate final table structure.
2. Implement constraints and indexes.
3. Implement Stored Procedures.
4. Implement repositories/data access.
5. Implement application use cases.
