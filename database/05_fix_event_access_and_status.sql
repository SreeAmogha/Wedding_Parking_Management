-- Compatibility repair script for older instructions. The canonical, idempotent schema and
-- access policies are in 01_create_tables.sql; event status refresh is in 04_event_status_and_access.sql.
-- This file deliberately does not create demo events or grant broader permissions.
SELECT public.refresh_wedding_event_statuses();
