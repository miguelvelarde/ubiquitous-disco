-- ============================================================
-- Condo Admin System
-- Dummy Data Population
-- ============================================================
-- Uses CRUD-stored-procedures.sql.
-- Run DDL-Tables.sql and CRUD-stored-procedures.sql first.
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS cas;
SET search_path = cas, public;

DO $$
DECLARE
    v_admin_id uuid;
    v_read_only_id uuid;

    v_owner_1_id uuid;
    v_owner_2_id uuid;
    v_owner_3_id uuid;

    v_recurring_catalog_id uuid;
    v_event_catalog_id uuid;
    v_extraordinary_catalog_id uuid;
    v_maintenance_catalog_id uuid;

    v_department_1_id uuid;
    v_department_2_id uuid;
    v_department_3_id uuid;

    v_amenity_1_id uuid;
    v_amenity_2_id uuid;

    v_recurring_service_1_id uuid;
    v_recurring_service_2_id uuid;

    v_reservation_1_id uuid;
    v_reservation_2_id uuid;
    v_maintenance_reservation_id uuid;

    v_charge_1_id uuid;
    v_charge_2_id uuid;
    v_payment_id uuid;
BEGIN
    -- --------------------------------------------------------
    -- USERS: required by created_by foreign keys.
    -- --------------------------------------------------------

    SELECT id INTO v_admin_id
      FROM cas.insert_user(
          'admin.demo',
          '$2a$ placeholder-demo-password-hash',
          'Admin'
      );

    SELECT id INTO v_read_only_id
      FROM cas.insert_user(
          'readonly.demo',
          '$2a$ placeholder-demo-password-hash',
          'ReadOnly'
      );

    -- --------------------------------------------------------
    -- OWNERS.
    -- --------------------------------------------------------

    SELECT id INTO v_owner_1_id
      FROM cas.insert_owner(
          'Ana Martinez',
          'ana.martinez@example.test',
          '+1-555-0101'
      );

    SELECT id INTO v_owner_2_id
      FROM cas.insert_owner(
          'Bruno Silva',
          'bruno.silva@example.test',
          '+1-555-0102'
      );

    SELECT id INTO v_owner_3_id
      FROM cas.insert_owner(
          'Carla Gomez',
          'carla.gomez@example.test',
          '+1-555-0103'
      );

    -- --------------------------------------------------------
    -- SERVICE CATALOG: required by recurring services,
    -- reservations and charges.
    -- --------------------------------------------------------

    SELECT id INTO v_recurring_catalog_id
      FROM cas.insert_service_catalog(
          'Monthly Condominium Fee',
          'Recurring monthly condominium administration fee.',
          'Recurring',
          125.00,
          true
      );

    SELECT id INTO v_event_catalog_id
      FROM cas.insert_service_catalog(
          'Community Room Reservation',
          'Charge for reserving the community room.',
          'Event',
          40.00,
          true
      );

    SELECT id INTO v_extraordinary_catalog_id
      FROM cas.insert_service_catalog(
          'Extraordinary Repair',
          'One-time extraordinary repair charge.',
          'Extraordinary',
          0.00,
          true
      );

    SELECT id INTO v_maintenance_catalog_id
      FROM cas.insert_service_catalog(
          'Amenity Maintenance Block',
          'Maintenance periods are represented as reservations.',
          'Event',
          0.00,
          true
      );

    -- --------------------------------------------------------
    -- DEPARTMENTS.
    -- --------------------------------------------------------

    SELECT id INTO v_department_1_id
      FROM cas.insert_department(
          v_owner_1_id,
          'Building A',
          '101',
          'Active'
      );

    SELECT id INTO v_department_2_id
      FROM cas.insert_department(
          v_owner_2_id,
          'Building A',
          '102',
          'Active'
      );

    SELECT id INTO v_department_3_id
      FROM cas.insert_department(
          v_owner_3_id,
          'Building B',
          '201',
          'Active'
      );

    -- --------------------------------------------------------
    -- OWNER HISTORY.
    -- --------------------------------------------------------

    PERFORM cas.insert_department_owner_history(
        v_department_1_id, v_owner_1_id, DATE '2026-01-01', NULL, v_admin_id
    );

    PERFORM cas.insert_department_owner_history(
        v_department_2_id, v_owner_2_id, DATE '2026-01-01', NULL, v_admin_id
    );

    PERFORM cas.insert_department_owner_history(
        v_department_3_id, v_owner_3_id, DATE '2026-01-01', NULL, v_admin_id
    );

    -- --------------------------------------------------------
    -- AMENITIES.
    -- --------------------------------------------------------

    SELECT id INTO v_amenity_1_id
      FROM cas.insert_amenity(
          'Community Room',
          'Multipurpose room for resident activities.',
          'Building A, ground floor',
          'Active'
      );

    SELECT id INTO v_amenity_2_id
      FROM cas.insert_amenity(
          'Swimming Pool',
          'Outdoor condominium swimming pool.',
          'Building B, courtyard',
          'Active'
      );

    -- --------------------------------------------------------
    -- RECURRING SERVICES.
    -- --------------------------------------------------------

    SELECT id INTO v_recurring_service_1_id
      FROM cas.insert_recurring_service(
          v_department_1_id,
          v_recurring_catalog_id,
          DATE '2026-01-01',
          NULL,
          DATE '2026-08-10',
          true
      );

    SELECT id INTO v_recurring_service_2_id
      FROM cas.insert_recurring_service(
          v_department_2_id,
          v_recurring_catalog_id,
          DATE '2026-01-01',
          NULL,
          DATE '2026-08-10',
          true
      );

    -- --------------------------------------------------------
    -- RESERVATIONS.
    -- Maintenance is a reservation using the maintenance catalog.
    -- --------------------------------------------------------

    SELECT id INTO v_reservation_1_id
      FROM cas.insert_reservation(
          v_amenity_1_id,
          v_department_1_id,
          v_event_catalog_id,
          timestamptz '2026-08-20 10:00:00+00',
          timestamptz '2026-08-20 12:00:00+00',
          'Confirmed'
      );

    SELECT id INTO v_reservation_2_id
      FROM cas.insert_reservation(
          v_amenity_2_id,
          v_department_2_id,
          v_event_catalog_id,
          timestamptz '2026-08-21 14:00:00+00',
          timestamptz '2026-08-21 16:00:00+00',
          'Confirmed'
      );

    SELECT id INTO v_maintenance_reservation_id
      FROM cas.insert_reservation(
          v_amenity_1_id,
          v_department_1_id,
          v_maintenance_catalog_id,
          timestamptz '2026-08-22 08:00:00+00',
          timestamptz '2026-08-22 18:00:00+00',
          'Confirmed'
      );

    -- --------------------------------------------------------
    -- CHARGES.
    -- --------------------------------------------------------

    SELECT id INTO v_charge_1_id
      FROM cas.insert_charge(
          v_department_1_id,
          v_recurring_catalog_id,
          v_recurring_service_1_id,
          NULL,
          'Recurring',
          202608,
          125.00,
          125.00,
          DATE '2026-08-10',
          'Paid',
          v_admin_id
      );

    SELECT id INTO v_charge_2_id
      FROM cas.insert_charge(
          v_department_1_id,
          v_event_catalog_id,
          NULL,
          v_reservation_1_id,
          'Reservation',
          NULL,
          40.00,
          40.00,
          DATE '2026-08-20',
          'Pending',
          v_admin_id
      );

    -- --------------------------------------------------------
    -- PAYMENTS.
    -- --------------------------------------------------------

    SELECT id INTO v_payment_id
      FROM cas.insert_payment(
          v_charge_1_id,
          timestamptz '2026-08-05 15:30:00+00',
          125.00,
          'Transfer',
          'DEMO-TRANSFER-0001',
          'Demo payment.',
          v_admin_id
      );

    -- Keep the generated identifiers used above referenced, making
    -- the dependency order explicit and preventing accidental removal.
    PERFORM v_read_only_id, v_recurring_service_2_id,
            v_reservation_2_id, v_maintenance_reservation_id,
            v_charge_2_id, v_payment_id, v_extraordinary_catalog_id;
END;
$$;

COMMIT;
