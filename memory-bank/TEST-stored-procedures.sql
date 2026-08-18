-- ============================================================
-- Condo Admin System
-- Stored Procedure Tests
-- ============================================================
--
-- Run DDL-Tables.sql, CRUD-stored-procedures.sql, and
-- BUSINESS-stored-procedures.sql first.
--
-- All test data is created through stored procedures.
-- Data is committed for post-test validation.
-- ============================================================

BEGIN;

SET LOCAL search_path = cas, public;

DO $$
DECLARE
    v_admin_id uuid;
    v_owner_1_id uuid;
    v_owner_2_id uuid;
    v_department_id uuid;
    v_amenity_id uuid;
    v_recurring_catalog_id uuid;
    v_catalog_id uuid;
    v_maintenance_catalog_id uuid;
    v_recurring_service_id uuid;
    v_reservation_id uuid;
    v_overlap_reservation_id uuid;
    v_cancel_reservation_id uuid;
    v_charge_id uuid;
    v_pending_charge_id uuid;
    v_result_id uuid;
    v_adjustment_id uuid;
    v_recurring_charge_id uuid;
    v_charge_count integer;
    v_payment_count integer;
    v_history_count integer;
    v_error_caught boolean;
    v_charge_status varchar(20);
    v_amount numeric(12,2);
    v_due_date date;
BEGIN
    -- --------------------------------------------------------
    -- Fixture data through CRUD procedures.
    -- --------------------------------------------------------

    SELECT id INTO v_admin_id
      FROM cas.insert_user(
          'sp-test-admin-' || replace(gen_random_uuid()::text, '-', ''),
          'test-hash',
          'Admin'
      );

    SELECT id INTO v_owner_1_id
      FROM cas.insert_owner(
          'Stored Procedure Owner 1',
          'sp-owner-1-' || replace(gen_random_uuid()::text, '-', '') || '@example.test',
          NULL
      );

    SELECT id INTO v_owner_2_id
      FROM cas.insert_owner(
          'Stored Procedure Owner 2',
          'sp-owner-2-' || replace(gen_random_uuid()::text, '-', '') || '@example.test',
          NULL
      );

    SELECT id INTO v_department_id
      FROM cas.insert_department(
          v_owner_1_id,
          'SP Test Building',
          'SP-' || substring(replace(gen_random_uuid()::text, '-', '') FROM 1 FOR 8),
          'Active'
      );

    SELECT id INTO v_amenity_id
      FROM cas.insert_amenity(
          'SP Test Amenity',
          'Stored procedure test amenity',
          'Test location',
          'Active'
      );

    SELECT id INTO v_recurring_catalog_id
      FROM cas.insert_service_catalog(
          'SP Test Recurring Service',
          NULL,
          'Recurring',
          125.00,
          true
      );

    SELECT id INTO v_catalog_id
      FROM cas.insert_service_catalog(
          'SP Test Reservation Service',
          NULL,
          'Event',
          50.00,
          true
      );

    SELECT id INTO v_maintenance_catalog_id
      FROM cas.insert_service_catalog(
          'SP Test Maintenance Service',
          'Maintenance periods are reservations.',
          'Event',
          0.00,
          true
      );

    PERFORM cas.insert_department_owner_history(
        v_department_id,
        v_owner_1_id,
        DATE '2026-01-01',
        NULL,
        v_admin_id
    );

    SELECT id INTO v_recurring_service_id
      FROM cas.insert_recurring_service(
          v_department_id,
          v_recurring_catalog_id,
          DATE '2026-01-01',
          NULL,
          DATE '2026-08-10',
          true
      );

    -- --------------------------------------------------------
    -- confirm_reservation: confirmation and charge creation.
    -- --------------------------------------------------------

    SELECT id INTO v_reservation_id
      FROM cas.insert_reservation(
          v_amenity_id,
          v_department_id,
          v_catalog_id,
          timestamptz '2026-08-20 10:00:00+00',
          timestamptz '2026-08-20 12:00:00+00',
          'Pending'
      );

    SELECT cas.confirm_reservation(
        v_reservation_id,
        50.00,
        DATE '2026-08-20',
        v_admin_id
    ) INTO v_result_id;

    IF v_result_id IS NULL THEN
        RAISE EXCEPTION 'TEST FAILED: confirm_reservation returned NULL';
    END IF;

    SELECT status INTO v_charge_status
      FROM charges
     WHERE id = v_result_id;

    IF v_charge_status <> 'Pending' THEN
        RAISE EXCEPTION 'TEST FAILED: confirmation charge status is %', v_charge_status;
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM reservations
         WHERE id = v_reservation_id
           AND status = 'Confirmed'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: reservation was not confirmed';
    END IF;

    -- Existing reservation blocks an overlapping reservation.
    SELECT id INTO v_overlap_reservation_id
      FROM cas.insert_reservation(
          v_amenity_id,
          v_department_id,
          v_catalog_id,
          timestamptz '2026-08-20 11:00:00+00',
          timestamptz '2026-08-20 13:00:00+00',
          'Pending'
      );

    v_error_caught := false;
    BEGIN
        PERFORM cas.confirm_reservation(
            v_overlap_reservation_id,
            50.00,
            DATE '2026-08-20',
            v_admin_id
        );
    EXCEPTION WHEN OTHERS THEN
        v_error_caught := true;
    END;

    IF NOT v_error_caught THEN
        RAISE EXCEPTION 'TEST FAILED: overlapping reservation was confirmed';
    END IF;

    -- Maintenance is represented by a reservation.
    PERFORM cas.insert_reservation(
        v_amenity_id,
        v_department_id,
        v_maintenance_catalog_id,
        timestamptz '2026-08-22 08:00:00+00',
        timestamptz '2026-08-22 18:00:00+00',
        'Confirmed'
    );

    -- --------------------------------------------------------
    -- cancel_reservation: cancellation and adjustment.
    -- --------------------------------------------------------

    SELECT id INTO v_cancel_reservation_id
      FROM cas.insert_reservation(
          v_amenity_id,
          v_department_id,
          v_catalog_id,
          timestamptz '2026-08-23 10:00:00+00',
          timestamptz '2026-08-23 12:00:00+00',
          'Confirmed'
      );

    SELECT cas.cancel_reservation(
        v_cancel_reservation_id,
        -50.00,
        v_admin_id
    ) INTO v_adjustment_id;

    IF v_adjustment_id IS NULL THEN
        RAISE EXCEPTION 'TEST FAILED: cancellation returned no adjustment';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM reservations
         WHERE id = v_cancel_reservation_id
           AND status = 'Cancelled'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: reservation was not cancelled';
    END IF;

    IF NOT EXISTS (
        SELECT 1
         FROM charges
         WHERE id = v_adjustment_id
           AND source_type = 'Adjustment'
           AND original_amount = 0
           AND amount = -50.00
           AND status = 'Paid'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: cancellation adjustment is incorrect';
    END IF;

    -- --------------------------------------------------------
    -- register_payment: exact payment and settlement.
    -- --------------------------------------------------------

    SELECT id INTO v_charge_id
      FROM charges
     WHERE reservation_id = v_reservation_id;

    -- register_payment creates the Payment and settles the Charge atomically.
    PERFORM cas.register_payment(
        v_charge_id,
        timestamptz '2026-08-05 15:30:00+00',
        50.00,
        'Transfer'::varchar(30),
        'SP-TEST-PAYMENT-REGISTER'::varchar(200),
        'Stored procedure payment test.'::varchar(1000),
        v_admin_id
    );

    IF NOT EXISTS (
        SELECT 1
          FROM charges
         WHERE id = v_charge_id
           AND status = 'Paid'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: charge was not marked Paid';
    END IF;

    SELECT count(*) INTO v_payment_count
      FROM payments
     WHERE charge_id = v_charge_id;

    IF v_payment_count <> 1 THEN
        RAISE EXCEPTION 'TEST FAILED: expected one payment, found %', v_payment_count;
    END IF;

    -- --------------------------------------------------------
    -- change_owner: owner history transition.
    -- --------------------------------------------------------

    PERFORM cas.change_owner(
        v_department_id,
        v_owner_2_id,
        DATE '2026-09-01',
        v_admin_id
    );

    IF NOT EXISTS (
        SELECT 1
          FROM departments
         WHERE id = v_department_id
           AND owner_id = v_owner_2_id
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: department owner was not changed';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM department_owner_history
         WHERE department_id = v_department_id
           AND owner_id = v_owner_1_id
           AND end_date = DATE '2026-08-31'
    ) THEN
        RAISE EXCEPTION 'TEST FAILED: previous owner history was not closed';
    END IF;

    SELECT count(*) INTO v_history_count
      FROM department_owner_history
     WHERE department_id = v_department_id
       AND end_date IS NULL;

    IF v_history_count <> 1 THEN
        RAISE EXCEPTION 'TEST FAILED: expected one current owner history row';
    END IF;

    -- --------------------------------------------------------
    -- generate_recurring_charges: generation and idempotency.
    -- --------------------------------------------------------

    SELECT count(*) INTO v_charge_count
      FROM cas.generate_recurring_charges(202608, v_admin_id)
     WHERE recurring_service_id = v_recurring_service_id;

    IF v_charge_count <> 1 THEN
        RAISE EXCEPTION 'TEST FAILED: expected one generated recurring charge';
    END IF;

    SELECT c.id, c.amount, c.due_date
      INTO v_recurring_charge_id, v_amount, v_due_date
      FROM charges c
     WHERE c.recurring_service_id = v_recurring_service_id
       AND c.billing_period = 202608;

    IF v_recurring_charge_id IS NULL
       OR v_amount <> 125.00
       OR v_due_date <> DATE '2026-08-10' THEN
        RAISE EXCEPTION 'TEST FAILED: generated recurring charge values are incorrect';
    END IF;

    SELECT count(*) INTO v_charge_count
      FROM cas.generate_recurring_charges(202608, v_admin_id)
     WHERE recurring_service_id = v_recurring_service_id;

    IF v_charge_count <> 1 THEN
        RAISE EXCEPTION 'TEST FAILED: idempotent generation returned no existing charge';
    END IF;

    IF (
        SELECT count(*)
          FROM charges
         WHERE recurring_service_id = v_recurring_service_id
           AND billing_period = 202608
    ) <> 1 THEN
        RAISE EXCEPTION 'TEST FAILED: recurring charge generation is not idempotent';
    END IF;

    RAISE NOTICE 'All stored procedure tests passed';
END;
$$;

COMMIT;
