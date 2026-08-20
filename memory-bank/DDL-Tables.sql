-- ============================================================
-- Condo Admin System
-- PostgreSQL Database Schema
-- Version: 0.4
-- Simplified service model
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cas;
SET search_path = cas, public;

-- Required for exclusion constraints with uuid + range operators.
CREATE EXTENSION IF NOT EXISTS btree_gist;


-- ============================================================
-- 1. OWNERS
-- ============================================================

CREATE TABLE owners (
    id              uuid PRIMARY KEY,
    name            varchar(200) NOT NULL,
    email           varchar(320),
    phone           varchar(50),
    created_at      timestamptz NOT NULL DEFAULT now()
);


-- ============================================================
-- 2. USERS
-- ============================================================

CREATE TABLE users (
    id              uuid PRIMARY KEY,
    username        varchar(150) NOT NULL UNIQUE,
    password_hash   varchar(200) NOT NULL,
    role            varchar(20) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_users_role
        CHECK (role IN ('Admin', 'ReadOnly'))
);


-- ============================================================
-- 3. DEPARTMENTS
-- ============================================================

CREATE TABLE departments (
    id              uuid PRIMARY KEY,
    owner_id        uuid NOT NULL,
    building        varchar(100) NOT NULL,
    number          varchar(50) NOT NULL,
    status          varchar(20) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_departments_owner
        FOREIGN KEY (owner_id)
        REFERENCES owners (id),

    CONSTRAINT ck_departments_status
        CHECK (status IN ('Active', 'Inactive')),

    CONSTRAINT uq_departments_building_number
        UNIQUE (building, number)
);


-- ============================================================
-- 4. DEPARTMENT OWNER HISTORY
-- ============================================================

CREATE TABLE department_owner_history (
    id              uuid PRIMARY KEY,
    department_id   uuid NOT NULL,
    owner_id        uuid NOT NULL,
    start_date      date NOT NULL,
    end_date        date,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid NOT NULL,

    CONSTRAINT fk_department_owner_history_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_department_owner_history_owner
        FOREIGN KEY (owner_id)
        REFERENCES owners (id),

    CONSTRAINT fk_department_owner_history_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    CONSTRAINT ck_department_owner_history_dates
        CHECK (
            end_date IS NULL
            OR end_date >= start_date
        )
);

CREATE UNIQUE INDEX ux_department_owner_history_current
    ON department_owner_history (department_id)
    WHERE end_date IS NULL;


-- ============================================================
-- 5. SERVICES
--
-- A Service is the single catalog of chargeable/reservable
-- concepts used by the application.
--
-- Types:
--   Recurring     - may participate in monthly charge generation.
--   Event         - event/reservation-related concept.
--   Extraordinary - discretionary non-recurring charge.
--   Adjustment    - accounting adjustment; charge amount may be
--                   positive or negative.
--
-- is_reservable identifies services that can be used as a
-- reservable resource in reservations.
-- ============================================================

CREATE TABLE services (
    id              uuid PRIMARY KEY,
    name            varchar(200) NOT NULL,
    description     varchar(1000),
    type            varchar(20) NOT NULL,
    default_amount  numeric(12,2) NOT NULL DEFAULT 0,
    is_reservable   boolean NOT NULL DEFAULT false,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_services_type
        CHECK (
            type IN (
                'Recurring',
                'Event',
                'Extraordinary',
                'Adjustment'
            )
        ),

    -- Normal services cannot have a negative configured amount.
    -- Adjustment services may define a negative default amount.
    CONSTRAINT ck_services_default_amount
        CHECK (
            type = 'Adjustment'
            OR default_amount >= 0
        )
);


-- ============================================================
-- 6. DEPARTMENT SERVICES
--
-- Current catalog of services permanently associated with a
-- Department.
--
-- No separate id and no audit/history fields are required.
-- Removing the row means the Department no longer participates
-- in future recurring generation for that Service.
-- ============================================================

CREATE TABLE department_services (
    department_id   uuid NOT NULL,
    service_id      uuid NOT NULL,

    CONSTRAINT pk_department_services
        PRIMARY KEY (department_id, service_id),

    CONSTRAINT fk_department_services_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_department_services_service
        FOREIGN KEY (service_id)
        REFERENCES services (id)
);


-- ============================================================
-- 7. RESERVATIONS
--
-- Reservation is independent from billing.
-- service_id identifies the reservable resource/concept.
--
-- department_id is nullable to support administrative blocks
-- such as maintenance that are not reservations by a Department.
--
-- Only Confirmed reservations participate in overlap blocking.
-- ============================================================

CREATE TABLE reservations (
    id                  uuid PRIMARY KEY,
    department_id       uuid,
    service_id          uuid NOT NULL,
    start_date_time     timestamptz NOT NULL,
    end_date_time       timestamptz NOT NULL,
    status              varchar(20) NOT NULL DEFAULT 'Confirmed',
    notes               varchar(1000),
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid NOT NULL,

    CONSTRAINT fk_reservations_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_reservations_service
        FOREIGN KEY (service_id)
        REFERENCES services (id),

    CONSTRAINT fk_reservations_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    CONSTRAINT ck_reservations_dates
        CHECK (
            end_date_time > start_date_time
        ),

    CONSTRAINT ck_reservations_status
        CHECK (
            status IN (
                'Confirmed',
                'Cancelled'
            )
        )
);

-- Same reservable Service cannot have overlapping active
-- reservations. [start, end) allows one reservation to begin
-- exactly when another one ends.
ALTER TABLE reservations
    ADD CONSTRAINT ex_reservations_no_overlap
    EXCLUDE USING gist (
        service_id WITH =,
        tstzrange(start_date_time, end_date_time, '[)') WITH &&
    )
    WHERE (status = 'Confirmed');


-- ============================================================
-- 8. CHARGES
--
-- Charge references only Department + Service.
-- It does not persist source_type and has no Reservation link.
--
-- BillingPeriod is mandatory for every Charge.
-- Default is the current YYYYMM period.
--
-- Adjustment is identified through services.type = 'Adjustment'.
-- Adjustment Charges may have negative amounts and are created
-- as Paid by application/domain behavior without a Payment.
-- ============================================================

CREATE TABLE charges (
    id                   uuid PRIMARY KEY,
    department_id        uuid NOT NULL,
    service_id           uuid NOT NULL,

    -- YYYYMM
    -- Example: 202608 = August 2026
    billing_period       integer NOT NULL
                         DEFAULT (to_char(CURRENT_DATE, 'YYYYMM')::integer),

    original_amount      numeric(12,2) NOT NULL,
    amount               numeric(12,2) NOT NULL,
    due_date             date NOT NULL,
    status               varchar(20) NOT NULL,

    created_at           timestamptz NOT NULL DEFAULT now(),
    created_by           uuid NOT NULL,

    CONSTRAINT fk_charges_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_charges_service
        FOREIGN KEY (service_id)
        REFERENCES services (id),

    CONSTRAINT fk_charges_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    CONSTRAINT ck_charges_billing_period
        CHECK (
            billing_period BETWEEN 190001 AND 999912
            AND (billing_period % 100) BETWEEN 1 AND 12
        ),

    CONSTRAINT ck_charges_status
        CHECK (
            status IN (
                'Pending',
                'Paid',
                'Waived',
                'Cancelled'
            )
        ),

    -- Zero-current-amount Charges are Waived.
    -- Adjustment charges may be negative; cross-table validation
    -- of negative amount vs services.type belongs to the
    -- application/domain operation that creates the Charge.
    CONSTRAINT ck_charges_zero_amount_waived
        CHECK (
            amount <> 0
            OR status = 'Waived'
        )
);


-- ============================================================
-- 9. PAYMENTS
--
-- One Charge can have at most one Payment.
-- Adjustment Charges that are created directly as Paid do not
-- require a Payment row.
-- ============================================================

CREATE TABLE payments (
    id              uuid PRIMARY KEY,
    charge_id       uuid NOT NULL,
    payment_date    timestamptz NOT NULL,
    amount          numeric(12,2) NOT NULL,
    payment_method  varchar(30) NOT NULL,
    reference       varchar(200) NOT NULL,
    notes           varchar(1000) NOT NULL DEFAULT 'Sin notas',
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid NOT NULL,

    CONSTRAINT fk_payments_charge
        FOREIGN KEY (charge_id)
        REFERENCES charges (id),

    CONSTRAINT fk_payments_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    CONSTRAINT uq_payments_charge
        UNIQUE (charge_id),

    CONSTRAINT ck_payments_amount
        CHECK (
            amount > 0
        ),

    CONSTRAINT ck_payments_method
        CHECK (
            payment_method IN (
                'Cash',
                'Card',
                'Transfer',
                'Other'
            )
        )
);


-- ============================================================
-- 10. INDEXES
-- ============================================================

CREATE INDEX ix_departments_owner_id
    ON departments (owner_id);

CREATE INDEX ix_department_owner_history_owner_id
    ON department_owner_history (owner_id);

CREATE INDEX ix_department_services_service_id
    ON department_services (service_id);

CREATE INDEX ix_reservations_department_id
    ON reservations (department_id);

CREATE INDEX ix_reservations_service_period
    ON reservations (
        service_id,
        start_date_time,
        end_date_time
    );

CREATE INDEX ix_charges_department_id
    ON charges (department_id);

CREATE INDEX ix_charges_service_id
    ON charges (service_id);

CREATE INDEX ix_charges_status_due_date
    ON charges (
        status,
        due_date
    );

CREATE INDEX ix_charges_billing_period
    ON charges (billing_period);


-- ============================================================
-- 11. RECURRING CHARGE IDEMPOTENCY
--
-- At most one recurring Charge may exist for a Department,
-- Service and BillingPeriod.
--
-- Because charges no longer persist source_type, uniqueness is
-- expressed over the actual recurring identity:
--
--   department_id + service_id + billing_period
--
-- The application generates recurring charges only from
-- department_services joined to services.type = 'Recurring'.
--
-- NOTE:
-- This unique index also prevents two non-recurring Charges for
-- the same Department + Service + BillingPeriod. If multiple
-- same-service event/extraordinary charges within one month must
-- be supported, this rule should instead be enforced by the
-- recurring-generation command/stored procedure.
-- ============================================================

-- Intentionally NOT created yet:
--
-- CREATE UNIQUE INDEX ux_charges_department_service_period
--     ON charges (department_id, service_id, billing_period);
--
-- See note above. Idempotency for recurring generation should be
-- enforced in the recurring-charge generation operation unless a
-- separate recurring identity is later introduced.


-- ============================================================
-- 12. TRIGGERS
-- Prevent changes to charges.original_amount after insert.
-- ============================================================

CREATE OR REPLACE FUNCTION prevent_original_amount_update()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.original_amount <> OLD.original_amount THEN
        RAISE EXCEPTION 'original_amount is immutable';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_charges_prevent_original_amount_update
BEFORE UPDATE ON charges
FOR EACH ROW
EXECUTE FUNCTION prevent_original_amount_update();
