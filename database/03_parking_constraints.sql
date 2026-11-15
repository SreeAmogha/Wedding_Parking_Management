-- These partial unique indexes are also created by database/01_create_tables.sql.
-- Retained as a standalone verification/repair script for existing installations.
CREATE UNIQUE INDEX IF NOT EXISTS parking_sessions_one_active_vehicle_uidx
    ON public.parking_sessions(vehicle_id) WHERE exit_time IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS parking_sessions_one_active_slot_uidx
    ON public.parking_sessions(slot_id) WHERE exit_time IS NULL;
