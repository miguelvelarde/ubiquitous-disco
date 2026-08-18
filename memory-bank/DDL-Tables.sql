-- ============================================================
-- Condo Admin System
-- PostgreSQL Database Schema
-- Version: 0.2
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cas;
SET search_path = cas, public;

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
-- 5. SERVICE CATALOG
-- ============================================================

CREATE TABLE service_catalog (
    id              uuid PRIMARY KEY,
    name            varchar(200) NOT NULL,
    description     varchar(1000),
    type            varchar(20) NOT NULL,
    default_amount  numeric(12,2) NOT NULL DEFAULT 0,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_service_catalog_type
        CHECK (type IN (
            'Recurring',
            'Event',
            'Extraordinary'
        )),

    CONSTRAINT ck_service_catalog_default_amount
        CHECK (default_amount >= 0)
);


-- ============================================================
-- 6. RECURRING SERVICES
-- ============================================================

CREATE TABLE recurring_services (
    id                  uuid PRIMARY KEY,
    department_id       uuid NOT NULL,
    service_catalog_id  uuid NOT NULL,
    start_date          date NOT NULL,
    end_date            date,
    due_date            date NOT NULL,
    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_recurring_services_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_recurring_services_service_catalog
        FOREIGN KEY (service_catalog_id)
        REFERENCES service_catalog (id),

    CONSTRAINT ck_recurring_services_dates
        CHECK (
            end_date IS NULL
            OR end_date >= start_date
        )
);


-- ============================================================
-- 7. AMENITIES
-- ============================================================

CREATE TABLE amenities (
    id              uuid PRIMARY KEY,
    name            varchar(200) NOT NULL,
    description     varchar(1000),
    location        varchar(500),
    status          varchar(20) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ck_amenities_status
        CHECK (status IN (
            'Active',
            'Inactive'
        ))
);


-- ============================================================
-- 8. RESERVATIONS
-- ============================================================

CREATE TABLE reservations (
    id                  uuid PRIMARY KEY,
    amenity_id          uuid NOT NULL,
    department_id       uuid NOT NULL,
    service_catalog_id  uuid NOT NULL,
    start_date_time     timestamptz NOT NULL,
    end_date_time       timestamptz NOT NULL,
    status              varchar(20) NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT fk_reservations_amenity
        FOREIGN KEY (amenity_id)
        REFERENCES amenities (id),

    CONSTRAINT fk_reservations_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_reservations_service_catalog
        FOREIGN KEY (service_catalog_id)
        REFERENCES service_catalog (id),

    CONSTRAINT ck_reservations_dates
        CHECK (
            end_date_time > start_date_time
        ),

    CONSTRAINT ck_reservations_status
        CHECK (status IN (
            'Pending',
            'Confirmed',
            'Cancelled',
            'Completed'
        ))
);



-- ============================================================
-- 10. CHARGES
-- ============================================================

CREATE TABLE charges (
    id                   uuid PRIMARY KEY,
    department_id        uuid NOT NULL,
    service_catalog_id   uuid NOT NULL,
    
    recurring_service_id uuid,

    reservation_id       uuid,
    source_type          varchar(20) NOT NULL,

    -- YYYYMM
    -- Example: 202608 = August 2026
    billing_period       integer,

    original_amount      numeric(12,2) NOT NULL,
    amount               numeric(12,2) NOT NULL,
    due_date             date NOT NULL,
    status               varchar(20) NOT NULL,

    created_at           timestamptz NOT NULL DEFAULT now(),
    created_by           uuid NOT NULL,

    CONSTRAINT fk_charges_department
        FOREIGN KEY (department_id)
        REFERENCES departments (id),

    CONSTRAINT fk_charges_service_catalog
        FOREIGN KEY (service_catalog_id)
        REFERENCES service_catalog (id),

    CONSTRAINT fk_charges_recurring_service
        FOREIGN KEY (recurring_service_id)
        REFERENCES recurring_services (id),

    -- recurring_service_id removed: use recurring_services for generation only

    CONSTRAINT fk_charges_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservations (id),

    CONSTRAINT fk_charges_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    -- --------------------------------------------------------
    -- Charge source
    -- --------------------------------------------------------

    CONSTRAINT ck_charges_source_type
        CHECK (
            source_type IN (
                'Recurring',
                'Reservation',
                'Extraordinary',
                'Adjustment'
            )
        ),

    CONSTRAINT ck_charges_source
        CHECK (
            (
                source_type = 'Recurring'
                AND recurring_service_id IS NOT NULL
                AND reservation_id IS NULL
            )
            OR
            (
                source_type = 'Reservation'
                AND recurring_service_id IS NULL
                AND reservation_id IS NOT NULL
            )
            OR
            (
                source_type = 'Extraordinary'
                AND recurring_service_id IS NULL
                AND reservation_id IS NULL
            )
            OR
            (
                source_type = 'Adjustment'
                AND recurring_service_id IS NULL
                AND reservation_id IS NULL
            )
        ),

    -- --------------------------------------------------------
    -- Billing period
    --
    -- YYYYMM
    -- 202601 = January 2026
    -- 202608 = August 2026
    -- 202612 = December 2026
    -- --------------------------------------------------------

    CONSTRAINT ck_charges_billing_period
        CHECK (
            billing_period IS NULL
            OR (
                billing_period BETWEEN 190001 AND 999912
                AND (billing_period % 100) BETWEEN 1 AND 12
            )
        ),

    -- --------------------------------------------------------
    -- Amounts
    -- --------------------------------------------------------

    CONSTRAINT ck_charges_amounts
        CHECK (
            (
                source_type = 'Adjustment'
                AND original_amount = 0
                AND amount <> 0
            )
            OR
            (
                source_type <> 'Adjustment'
                AND original_amount >= 0
                AND amount >= 0
                AND amount <= original_amount
            )
        ),

    -- --------------------------------------------------------
    -- Status
    -- --------------------------------------------------------

    CONSTRAINT ck_charges_status
        CHECK (
            status IN (
                'Pending',
                'Paid',
                'Waived',
                'Cancelled'
            )
        ),

    -- An adjustment is applied immediately and never receives a Payment.
    CONSTRAINT ck_charges_adjustment_status
        CHECK (
            source_type <> 'Adjustment'
            OR status = 'Paid'
        )
);


-- ============================================================
-- 11. PAYMENTS
-- ============================================================

CREATE TABLE payments (
    id              uuid PRIMARY KEY,
    charge_id       uuid NOT NULL,
    payment_date    timestamptz NOT NULL,
    amount          numeric(12,2) NOT NULL,
    payment_method  varchar(30) NOT NULL,
    reference       varchar(200) NOT NULL,
    notes           varchar(1000),
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid NOT NULL,

    CONSTRAINT fk_payments_charge
        FOREIGN KEY (charge_id)
        REFERENCES charges (id),

    CONSTRAINT fk_payments_created_by
        FOREIGN KEY (created_by)
        REFERENCES users (id),

    -- One Charge can have at most one Payment.
    CONSTRAINT uq_payments_charge
        UNIQUE (charge_id),

    CONSTRAINT ck_payments_amount
        CHECK (
            amount > 0
        ),

    CONSTRAINT ck_payments_method
        CHECK (
            payment_method IN ('Cash','Card','Transfer','Other')
        )
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX ix_departments_owner_id
    ON departments (owner_id);


CREATE INDEX ix_department_owner_history_owner_id
    ON department_owner_history (owner_id);


CREATE INDEX ix_recurring_services_department_id
    ON recurring_services (department_id);


CREATE INDEX ix_recurring_services_service_catalog_id
    ON recurring_services (service_catalog_id);


CREATE INDEX ix_reservations_amenity_period
    ON reservations (
        amenity_id,
        start_date_time,
        end_date_time
    );


CREATE INDEX ix_reservations_department_id
    ON reservations (department_id);


CREATE INDEX ix_charges_department_id
    ON charges (department_id);


CREATE INDEX ix_charges_status_due_date
    ON charges (
        status,
        due_date
    );


CREATE INDEX ix_charges_billing_period
    ON charges (billing_period);


-- ============================================================
-- IDEMPOTENCY
--
-- A recurring service can generate at most one Charge
-- for a given BillingPeriod.
--
-- Example:
-- RecurringService = X
-- BillingPeriod    = 202608
--
-- Only one recurring Charge is allowed.
-- ============================================================

CREATE UNIQUE INDEX ux_charges_recurring_period
        ON charges (recurring_service_id, billing_period)
        WHERE source_type = 'Recurring'
            AND recurring_service_id IS NOT NULL
            AND billing_period IS NOT NULL;


-- ============================================================
-- TRIGGERS
-- Prevent changes to charges.original_amount after insert
-- ============================================================

CREATE OR REPLACE FUNCTION prevent_original_amount_update()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.original_amount <> OLD.original_amount THEN
        RAISE EXCEPTION 'original_amount is immutable';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_charges_prevent_original_amount_update
BEFORE UPDATE ON charges
FOR EACH ROW EXECUTE FUNCTION prevent_original_amount_update();


-- An Adjustment Charge records an administrative accounting effect directly.
-- It must not receive a cash Payment.
CREATE OR REPLACE FUNCTION prevent_payment_for_adjustment_charge()
RETURNS trigger AS $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM charges
         WHERE id = NEW.charge_id
           AND source_type = 'Adjustment'
    ) THEN
        RAISE EXCEPTION 'Adjustment charges cannot receive payments';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payments_prevent_adjustment_charge_payment
BEFORE INSERT OR UPDATE OF charge_id ON payments
FOR EACH ROW EXECUTE FUNCTION prevent_payment_for_adjustment_charge();
