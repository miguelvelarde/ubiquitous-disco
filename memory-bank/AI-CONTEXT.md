# AI Context — Condominium Administration System

**Version:** 1.0  
**Status:** Final implementation baseline  
**Date:** 2026-08-16

## Source of Truth

Before implementing or changing code, consult:
- `DOMAIN-MODEL.md` — business/domain rules.
- `DATABASE-DESIGN.md` — PostgreSQL and persistence.
- `ARCHITECTURE.md` — technical architecture.

If a requested implementation conflicts with these documents, identify the conflict instead of silently inventing a new rule.

## Project

C#/.NET + PostgreSQL + Blazor. Monolithic. One active user at a time. DDD used pragmatically. No distributed architecture and no required background processing.

PostgreSQL objects are namespaced under the `cas` schema. Apply `DDL-Tables.sql`, then `CRUD-stored-procedures.sql`, then `BUSINESS-stored-procedures.sql`; application SQL should qualify objects with `cas.` or use `search_path = cas, public`.

## Aggregates

```text
Charge Aggregate
    Charge
    └── Payment

Reservation Aggregate
    Reservation
```

Reservation and Charge are independent Aggregates.

## Critical Rules

- No partial payments.
- A Charge can be paid only once.
- Charge terminal states: `Paid`, `Waived`, `Cancelled`.
- Zero-amount Charges are `Waived`.
- `OriginalAmount` never changes.
- `Charge.Waive()` sets `Amount = 0`.
- Charge does not query other entities or repositories.
- Charge creation receives its amount as an input.
- Paid Charge reversal uses a new `ChargeAdjustment`.
- Historical financial records are not modified to hide later events.
- Reservation confirmation + Charge creation is atomic.
- Reservation cannot overlap another Reservation.
- Maintenance is represented by a Reservation with a maintenance ServiceCatalog entry.
- First existing availability record has priority.
- Recurring charge generation is idempotent.
- Tariff changes affect future Charges only.
- A recurring service starting during a month generates the full month; no proration.
- BillingPeriod is integer `YYYYMM`.
- Overdue begins immediately after DueDate and is not a persisted Charge state.
- No automatic overdue surcharge rules.
- Extraordinary Charges use ServiceCatalog.
- ChargeAdjustment reasons/applicability are discretionary.
- Promotions are discretionary; no promotion engine.
- Administrative Charge cancellation is discretionary.
- Future payment methods are out of scope.

## Authorization

```text
Admin
    Commands + Queries

ReadOnly
    Queries only
```

ReadOnly cannot create, modify, cancel, pay, waive, generate, reserve or otherwise change persistent state. Enforce authorization server-side.

## Audit

Keep auditing simple:

```text
created_at
created_by
```

where creator identification is relevant. Do not introduce `updated_by`, `updated_at`, generic `AuditLog`, snapshots or field-level history.

## Architecture Rules

- Domain must not depend on Infrastructure.
- Domain entities must not query repositories.
- Application coordinates use cases and transactions.
- Database constraints are the final integrity layer.
- Stored Procedures may perform cross-record queries when that simplifies atomic operations.
- Queries may use direct SQL/projections without loading Aggregates.
- Avoid unnecessary DDD abstractions.

## Scope Philosophy

Do not automatically implement business rules for overdue surcharges, ChargeAdjustment reasons, extraordinary charges, promotions or administrative Charge cancellation. These are intentionally discretionary administrator operations.

## Implementation Priority

1. Validate DDL.
2. Implement constraints/indexes.
3. Implement Stored Procedures.
4. Implement Domain.
5. Implement Application use cases.
6. Implement persistence/repositories.
7. Implement authentication/authorization.
8. Implement UI and queries.
