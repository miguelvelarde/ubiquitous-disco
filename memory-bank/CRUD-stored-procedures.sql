-- ============================================================
-- Condo Admin System
-- CRUD Stored Procedures / PostgreSQL Functions
-- Version: 1.0
-- ============================================================
--
-- Inserts generate id and created_at inside the procedure.
-- Updates require the primary key.
-- Foreign-key validity and other integrity rules remain enforced
-- by the database constraints in DDL-Tables.sql.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS cas;
SET search_path = cas, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- OWNERS
-- ============================================================

CREATE OR REPLACE FUNCTION insert_owner(
    p_name varchar(200),
    p_email varchar(320),
    p_phone varchar(50)
)
RETURNS SETOF owners
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO owners (id, name, email, phone, created_at)
    VALUES (gen_random_uuid(), p_name, p_email, p_phone, now())
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_owner(
    p_id uuid,
    p_name varchar(200),
    p_email varchar(320),
    p_phone varchar(50)
)
RETURNS SETOF owners
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE owners
       SET name = p_name,
           email = p_email,
           phone = p_phone
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- USERS
-- ============================================================

CREATE OR REPLACE FUNCTION insert_user(
    p_username varchar(150),
    p_password_hash varchar(200),
    p_role varchar(20)
)
RETURNS SETOF users
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO users (id, username, password_hash, role, created_at)
    VALUES (gen_random_uuid(), p_username, p_password_hash, p_role, now())
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_user(
    p_id uuid,
    p_username varchar(150),
    p_password_hash varchar(200),
    p_role varchar(20)
)
RETURNS SETOF users
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE users
       SET username = p_username,
           password_hash = p_password_hash,
           role = p_role
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- DEPARTMENTS
-- ============================================================

CREATE OR REPLACE FUNCTION insert_department(
    p_owner_id uuid,
    p_building varchar(100),
    p_number varchar(50),
    p_status varchar(20)
)
RETURNS SETOF departments
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO departments (
        id, owner_id, building, number, status, created_at
    )
    VALUES (
        gen_random_uuid(), p_owner_id, p_building, p_number, p_status,
        now()
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_department(
    p_id uuid,
    p_owner_id uuid,
    p_building varchar(100),
    p_number varchar(50),
    p_status varchar(20)
)
RETURNS SETOF departments
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE departments
       SET owner_id = p_owner_id,
           building = p_building,
           number = p_number,
           status = p_status
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- DEPARTMENT OWNER HISTORY
-- ============================================================

CREATE OR REPLACE FUNCTION insert_department_owner_history(
    p_department_id uuid,
    p_owner_id uuid,
    p_start_date date,
    p_end_date date,
    p_created_by uuid
)
RETURNS SETOF department_owner_history
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO department_owner_history (
        id, department_id, owner_id, start_date, end_date,
        created_at, created_by
    )
    VALUES (
        gen_random_uuid(), p_department_id, p_owner_id, p_start_date,
        p_end_date, now(), p_created_by
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_department_owner_history(
    p_id uuid,
    p_department_id uuid,
    p_owner_id uuid,
    p_start_date date,
    p_end_date date,
    p_created_by uuid
)
RETURNS SETOF department_owner_history
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE department_owner_history
       SET department_id = p_department_id,
           owner_id = p_owner_id,
           start_date = p_start_date,
           end_date = p_end_date,
           created_by = p_created_by
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- SERVICE CATALOG
-- ============================================================

CREATE OR REPLACE FUNCTION insert_service_catalog(
    p_name varchar(200),
    p_description varchar(1000),
    p_type varchar(20),
    p_default_amount numeric(12,2),
    p_is_active boolean
)
RETURNS SETOF service_catalog
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO service_catalog (
        id, name, description, type, default_amount, is_active, created_at
    )
    VALUES (
        gen_random_uuid(), p_name, p_description, p_type,
        p_default_amount, p_is_active, now()
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_service_catalog(
    p_id uuid,
    p_name varchar(200),
    p_description varchar(1000),
    p_type varchar(20),
    p_default_amount numeric(12,2),
    p_is_active boolean
)
RETURNS SETOF service_catalog
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE service_catalog
       SET name = p_name,
           description = p_description,
           type = p_type,
           default_amount = p_default_amount,
           is_active = p_is_active
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- RECURRING SERVICES
-- ============================================================

CREATE OR REPLACE FUNCTION insert_recurring_service(
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_start_date date,
    p_end_date date,
    p_due_date date,
    p_is_active boolean
)
RETURNS SETOF recurring_services
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO recurring_services (
        id, department_id, service_catalog_id, start_date, end_date,
        due_date, is_active, created_at
    )
    VALUES (
        gen_random_uuid(), p_department_id, p_service_catalog_id,
        p_start_date, p_end_date, p_due_date, p_is_active, now()
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_recurring_service(
    p_id uuid,
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_start_date date,
    p_end_date date,
    p_due_date date,
    p_is_active boolean
)
RETURNS SETOF recurring_services
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE recurring_services
       SET department_id = p_department_id,
           service_catalog_id = p_service_catalog_id,
           start_date = p_start_date,
           end_date = p_end_date,
           due_date = p_due_date,
           is_active = p_is_active
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- AMENITIES
-- ============================================================

CREATE OR REPLACE FUNCTION insert_amenity(
    p_name varchar(200),
    p_description varchar(1000),
    p_location varchar(500),
    p_status varchar(20)
)
RETURNS SETOF amenities
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO amenities (
        id, name, description, location, status, created_at
    )
    VALUES (
        gen_random_uuid(), p_name, p_description, p_location, p_status, now()
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_amenity(
    p_id uuid,
    p_name varchar(200),
    p_description varchar(1000),
    p_location varchar(500),
    p_status varchar(20)
)
RETURNS SETOF amenities
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE amenities
       SET name = p_name,
           description = p_description,
           location = p_location,
           status = p_status
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- RESERVATIONS
-- ============================================================

CREATE OR REPLACE FUNCTION insert_reservation(
    p_amenity_id uuid,
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_start_date_time timestamptz,
    p_end_date_time timestamptz,
    p_status varchar(20)
)
RETURNS SETOF reservations
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO reservations (
        id, amenity_id, department_id, service_catalog_id,
        start_date_time, end_date_time, status, created_at
    )
    VALUES (
        gen_random_uuid(), p_amenity_id, p_department_id,
        p_service_catalog_id, p_start_date_time, p_end_date_time,
        p_status, now()
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_reservation(
    p_id uuid,
    p_amenity_id uuid,
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_start_date_time timestamptz,
    p_end_date_time timestamptz,
    p_status varchar(20)
)
RETURNS SETOF reservations
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE reservations
       SET amenity_id = p_amenity_id,
           department_id = p_department_id,
           service_catalog_id = p_service_catalog_id,
           start_date_time = p_start_date_time,
           end_date_time = p_end_date_time,
           status = p_status
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- CHARGES
-- ============================================================

CREATE OR REPLACE FUNCTION insert_charge(
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_recurring_service_id uuid,
    p_reservation_id uuid,
    p_source_type varchar(20),
    p_billing_period integer,
    p_original_amount numeric(12,2),
    p_amount numeric(12,2),
    p_due_date date,
    p_status varchar(20),
    p_created_by uuid
)
RETURNS SETOF charges
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO charges (
        id, department_id, service_catalog_id, recurring_service_id,
        reservation_id, source_type, billing_period, original_amount,
        amount, due_date, status, created_at, created_by
    )
    VALUES (
        gen_random_uuid(), p_department_id, p_service_catalog_id,
        p_recurring_service_id, p_reservation_id, p_source_type,
        p_billing_period, p_original_amount, p_amount, p_due_date,
        p_status, now(), p_created_by
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_charge(
    p_id uuid,
    p_department_id uuid,
    p_service_catalog_id uuid,
    p_recurring_service_id uuid,
    p_reservation_id uuid,
    p_source_type varchar(20),
    p_billing_period integer,
    p_original_amount numeric(12,2),
    p_amount numeric(12,2),
    p_due_date date,
    p_status varchar(20),
    p_created_by uuid
)
RETURNS SETOF charges
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE charges
       SET department_id = p_department_id,
           service_catalog_id = p_service_catalog_id,
           recurring_service_id = p_recurring_service_id,
           reservation_id = p_reservation_id,
           source_type = p_source_type,
           billing_period = p_billing_period,
           original_amount = p_original_amount,
           amount = p_amount,
           due_date = p_due_date,
           status = p_status,
           created_by = p_created_by
     WHERE id = p_id
     RETURNING *;
END;
$$;


-- ============================================================
-- PAYMENTS
-- ============================================================

CREATE OR REPLACE FUNCTION insert_payment(
    p_charge_id uuid,
    p_payment_date timestamptz,
    p_amount numeric(12,2),
    p_payment_method varchar(30),
    p_reference varchar(200),
    p_notes varchar(1000),
    p_created_by uuid
)
RETURNS SETOF payments
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO payments (
        id, charge_id, payment_date, amount, payment_method,
        reference, notes, created_at, created_by
    )
    VALUES (
        gen_random_uuid(), p_charge_id, p_payment_date, p_amount,
        p_payment_method, p_reference, p_notes, now(), p_created_by
    )
    RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION update_payment(
    p_id uuid,
    p_charge_id uuid,
    p_payment_date timestamptz,
    p_amount numeric(12,2),
    p_payment_method varchar(30),
    p_reference varchar(200),
    p_notes varchar(1000),
    p_created_by uuid
)
RETURNS SETOF payments
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE payments
       SET charge_id = p_charge_id,
           payment_date = p_payment_date,
           amount = p_amount,
           payment_method = p_payment_method,
           reference = p_reference,
           notes = p_notes,
           created_by = p_created_by
     WHERE id = p_id
     RETURNING *;
END;
$$;
