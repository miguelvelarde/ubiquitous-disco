-- ============================================================
-- Condo Admin System
-- Stored Procedures / PostgreSQL Functions
-- Version: 1.0
-- ============================================================
--
-- Prerequisites:
-- 1. Run DDL-Tables.sql first.
--
-- All write functions are intended to be called inside the application
-- transaction boundary. Row/advisory locks protect cross-record checks.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cas;
SET search_path = cas, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Database-level idempotency guarantee for recurring charge generation.
CREATE UNIQUE INDEX IF NOT EXISTS ux_charges_recurring_period
    ON charges (recurring_service_id, billing_period)
    WHERE source_type = 'Recurring'
      AND recurring_service_id IS NOT NULL
      AND billing_period IS NOT NULL;


-- ============================================================
-- 1. CONFIRM RESERVATION + CREATE CHARGE
-- ============================================================

CREATE OR REPLACE FUNCTION confirm_reservation(
    p_reservation_id uuid,
    p_amount numeric(12,2),
    p_due_date date,
    p_created_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation reservations%ROWTYPE;
    v_charge_id uuid := gen_random_uuid();
    v_charge_status varchar(20);
BEGIN
    IF p_amount IS NULL OR p_amount < 0 THEN
        RAISE EXCEPTION 'Reservation charge amount must be non-negative';
    END IF;

    SELECT *
      INTO v_reservation
      FROM reservations
     WHERE id = p_reservation_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % does not exist', p_reservation_id;
    END IF;

    IF v_reservation.status <> 'Pending' THEN
        RAISE EXCEPTION 'Reservation % is not pending', p_reservation_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM amenities
         WHERE id = v_reservation.amenity_id
           AND status = 'Active'
    ) THEN
        RAISE EXCEPTION 'Amenity % is not active', v_reservation.amenity_id;
    END IF;

    -- Serialize reservations for this amenity before checking overlap.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_reservation.amenity_id::text, 0)
    );

    IF EXISTS (
        SELECT 1
          FROM reservations r
         WHERE r.amenity_id = v_reservation.amenity_id
           AND r.id <> v_reservation.id
           AND r.status IN ('Pending', 'Confirmed', 'Completed')
           AND r.start_date_time < v_reservation.end_date_time
           AND r.end_date_time > v_reservation.start_date_time
    ) THEN
        RAISE EXCEPTION 'Reservation % overlaps an existing reservation',
            p_reservation_id;
    END IF;

    v_charge_status := CASE WHEN p_amount = 0 THEN 'Waived' ELSE 'Pending' END;

    UPDATE reservations
       SET status = 'Confirmed'
     WHERE id = p_reservation_id;

    INSERT INTO charges (
        id, department_id, service_catalog_id, reservation_id,
        source_type, original_amount, amount, due_date, status,
        created_by
    )
    VALUES (
        v_charge_id, v_reservation.department_id,
        v_reservation.service_catalog_id, p_reservation_id,
        'Reservation', p_amount, p_amount, p_due_date,
        v_charge_status, p_created_by
    );

    RETURN v_charge_id;
END;
$$;


-- ============================================================
-- 2. CANCEL RESERVATION + OPTIONAL ADJUSTMENT CHARGE
-- ============================================================

CREATE OR REPLACE FUNCTION cancel_reservation(
    p_reservation_id uuid,
    p_adjustment_amount numeric(12,2),
    p_created_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation reservations%ROWTYPE;
    v_adjustment_id uuid;
BEGIN
    IF p_adjustment_amount IS NULL THEN
        RAISE EXCEPTION 'Adjustment amount must be provided; use 0 for no adjustment';
    END IF;

    SELECT *
      INTO v_reservation
      FROM reservations
     WHERE id = p_reservation_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % does not exist', p_reservation_id;
    END IF;

    IF v_reservation.status = 'Cancelled' THEN
        RAISE EXCEPTION 'Reservation % is already cancelled', p_reservation_id;
    END IF;

    UPDATE reservations
       SET status = 'Cancelled'
     WHERE id = p_reservation_id;

    IF p_adjustment_amount = 0 THEN
        RETURN NULL;
    END IF;

    v_adjustment_id := gen_random_uuid();

    INSERT INTO charges (
        id, department_id, service_catalog_id, source_type,
        original_amount, amount, due_date, status, created_by
    )
    VALUES (
        v_adjustment_id, v_reservation.department_id,
        v_reservation.service_catalog_id, 'Adjustment',
        0, p_adjustment_amount, CURRENT_DATE, 'Paid',
        p_created_by
    );

    RETURN v_adjustment_id;
END;
$$;


-- ============================================================
-- 3. REGISTER PAYMENT + SETTLE CHARGE
-- ============================================================

DROP FUNCTION IF EXISTS register_payment(
    uuid,
    uuid,
    timestamptz,
    numeric,
    varchar,
    varchar,
    varchar,
    uuid
);

CREATE OR REPLACE FUNCTION register_payment(
    p_charge_id uuid,
    p_payment_date timestamptz,
    p_amount numeric(12,2),
    p_payment_method varchar(30),
    p_reference varchar(200),
    p_notes varchar(1000),
    p_created_by uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_charge charges%ROWTYPE;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be positive';
    END IF;

    SELECT *
      INTO v_charge
      FROM charges
     WHERE id = p_charge_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Charge % does not exist', p_charge_id;
    END IF;

    IF v_charge.status <> 'Pending' THEN
        RAISE EXCEPTION 'Charge % is not pending', p_charge_id;
    END IF;

    IF p_amount <> v_charge.amount THEN
        RAISE EXCEPTION
            'Partial payments are not allowed; expected %, received %',
            v_charge.amount, p_amount;
    END IF;

    INSERT INTO payments (
        id, charge_id, payment_date, amount, payment_method,
        reference, notes, created_by
    )
    VALUES (
        gen_random_uuid(), p_charge_id, p_payment_date, p_amount,
        p_payment_method, p_reference, p_notes, p_created_by
    );

    UPDATE charges
       SET status = 'Paid'
     WHERE id = p_charge_id;
END;
$$;


-- ============================================================
-- 4. CHANGE OWNER + CLOSE/CREATE OWNER HISTORY
-- ============================================================

CREATE OR REPLACE FUNCTION change_owner(
    p_department_id uuid,
    p_new_owner_id uuid,
    p_effective_date date,
    p_created_by uuid
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM 1
      FROM departments
     WHERE id = p_department_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Department % does not exist', p_department_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM owners WHERE id = p_new_owner_id) THEN
        RAISE EXCEPTION 'Owner % does not exist', p_new_owner_id;
    END IF;

    IF p_effective_date IS NULL THEN
        RAISE EXCEPTION 'Effective date is required';
    END IF;

    UPDATE department_owner_history
       SET end_date = p_effective_date - 1
     WHERE department_id = p_department_id
       AND end_date IS NULL;

    UPDATE departments
       SET owner_id = p_new_owner_id
     WHERE id = p_department_id;

    INSERT INTO department_owner_history (
        id, department_id, owner_id, start_date, end_date,
        created_at, created_by
    )
    VALUES (
        gen_random_uuid(), p_department_id, p_new_owner_id,
        p_effective_date, NULL,
        now(), p_created_by
    );
END;
$$;


-- ============================================================
-- 5. GENERATE RECURRING CHARGES
-- ============================================================

CREATE OR REPLACE FUNCTION generate_recurring_charges(
    p_billing_period integer,
    p_created_by uuid
)
RETURNS TABLE (
    recurring_service_id uuid,
    charge_id uuid,
    created boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_period_start date;
    v_period_end date;
    v_due_date date;
    v_service recurring_services%ROWTYPE;
    v_charge_id uuid;
BEGIN
    IF p_billing_period IS NULL
       OR p_billing_period < 190001
       OR p_billing_period > 999912
       OR p_billing_period % 100 NOT BETWEEN 1 AND 12 THEN
        RAISE EXCEPTION 'Invalid billing period %', p_billing_period;
    END IF;

    v_period_start := make_date(p_billing_period / 100, p_billing_period % 100, 1);
    v_period_end := (v_period_start + INTERVAL '1 month - 1 day')::date;

    FOR v_service IN
        SELECT rs.*
          FROM recurring_services rs
          JOIN service_catalog sc ON sc.id = rs.service_catalog_id
         WHERE rs.is_active
           AND sc.is_active
           AND rs.start_date <= v_period_end
           AND (rs.end_date IS NULL OR rs.end_date >= v_period_start)
         ORDER BY rs.id
    LOOP
        PERFORM pg_advisory_xact_lock(
            hashtextextended(v_service.id::text || ':' || p_billing_period::text, 0)
        );

        SELECT c.id
          INTO v_charge_id
          FROM charges c
         WHERE c.recurring_service_id = v_service.id
           AND c.billing_period = p_billing_period
           AND c.source_type = 'Recurring';

        IF FOUND THEN
            recurring_service_id := v_service.id;
            charge_id := v_charge_id;
            created := false;
            RETURN NEXT;
            CONTINUE;
        END IF;

        v_due_date := make_date(
            EXTRACT(YEAR FROM v_period_start)::integer,
            EXTRACT(MONTH FROM v_period_start)::integer,
            LEAST(
                EXTRACT(DAY FROM v_service.due_date)::integer,
                EXTRACT(DAY FROM v_period_end)::integer
            )
        );

        v_charge_id := gen_random_uuid();

        INSERT INTO charges (
            id, department_id, service_catalog_id, recurring_service_id,
            source_type, billing_period, original_amount, amount,
            due_date, status, created_by
        )
        VALUES (
            v_charge_id, v_service.department_id, v_service.service_catalog_id,
            v_service.id, 'Recurring', p_billing_period,
            (SELECT default_amount FROM service_catalog WHERE id = v_service.service_catalog_id),
            (SELECT default_amount FROM service_catalog WHERE id = v_service.service_catalog_id),
            v_due_date,
            CASE
                WHEN (SELECT default_amount FROM service_catalog WHERE id = v_service.service_catalog_id) = 0
                    THEN 'Waived'
                ELSE 'Pending'
            END,
            p_created_by
        );

        recurring_service_id := v_service.id;
        charge_id := v_charge_id;
        created := true;
        RETURN NEXT;
    END LOOP;
END;
$$;
