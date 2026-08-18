# Architecture — Condominium Administration System

**Version:** 1.0  
**Status:** Final baseline for implementation  
**Date:** 2026-08-16

## 1. Goals

Simple, maintainable, strongly consistent architecture for a single-user-at-a-time monolithic system. Avoid distributed-system patterns.

## 2. Logical Layers

```text
Presentation
    │
    ▼
Application
    │
    ▼
Domain
    ▲
    │
Infrastructure
    │
    ▼
PostgreSQL
```

## 3. Domain Layer

Contains Entities, Aggregate Roots, Value Objects, Domain Services and domain rules. It must not depend on PostgreSQL, repository implementations, HTTP, Blazor or external services. Domain entities must not query repositories.

## 4. Application Layer

Responsible for use cases, orchestration, required data retrieval, multi-Aggregate coordination, transaction boundaries, authorization at the application boundary and DTO mapping where appropriate.

Examples: `ConfirmReservation`, `CancelReservation`, `RegisterPayment`, `GenerateRecurringCharges`, `ChangeOwner`.

## 5. Infrastructure Layer

Contains PostgreSQL access, repositories, Stored Procedure calls, authentication persistence and logging infrastructure.

PostgreSQL tables and functions are deployed in the `cas` schema. Infrastructure calls should use qualified names such as `cas.confirm_reservation`.

## 6. Aggregates

Current Aggregate Roots:

```text
Charge
Reservation
```

Charge contains Payment. Reservation does not contain Charge.

## 7. Transactions

The Application Layer defines the business operation and transaction boundary. PostgreSQL/Stored Procedures may implement the atomic operation.

Examples:

```text
ConfirmReservation -> Reservation + Charge
CancelReservation  -> Reservation + Adjustment Charge
RegisterPayment    -> Charge + Payment
ChangeOwner        -> Department + OwnerHistory
```

A use case succeeds completely or rolls back.

## 8. Commands and Queries

Commands modify state. Queries only read.

Queries do not need to load Aggregates and may use direct SQL/projections/read models for account statements, payment history, summaries, reservation listings and reports.

## 9. Authorization

### Admin
Commands + Queries.

### ReadOnly
Queries only.

ReadOnly cannot execute any operation that changes persistent state. Authorization is enforced server-side; UI restrictions are not a security boundary.

## 10. Users

Minimum information: UserId, Username, PasswordHash, Role. Authentication mechanism is an implementation concern; the domain requires an authenticated identity and role.

## 11. Audit

No generic AuditLog. Where relevant, records store `created_at` and `created_by`. No `updated_at`, `updated_by`, snapshots or generic field-change history.

The authenticated user's identity must be available to Application/Infrastructure when creating records.

## 12. Domain Events

Not required initially. There are no current asynchronous consumers and the system is not distributed. Revisit only if a concrete requirement appears.

## 13. Stored Procedures

Stored Procedures are acceptable when they simplify atomic operations and cross-record validation. The application may pass values already obtained by the UI/application or allow the procedure to obtain required values internally. Charge itself never queries other entities/repositories.

## 14. Error Handling

Domain/application errors should be translated into meaningful application responses. Database constraint violations remain a final integrity layer and should be translated rather than exposed as raw database errors.

## 15. Simplicity Rules

Do not introduce distributed transactions, message buses, asynchronous workflows, generic domain-event infrastructure, complex authorization matrices, generic audit logging, or abstractions without a current business need.

## 16. Implementation Sequence

1. PostgreSQL DDL.
2. Constraints and indexes.
3. Stored Procedures.
4. Domain.
5. Application use cases.
6. Persistence/repositories.
7. Authentication/authorization.
8. UI and queries.
9. Integration/end-to-end validation.
