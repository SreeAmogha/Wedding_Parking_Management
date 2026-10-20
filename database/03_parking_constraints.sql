
--SAFE GUARDS?--
CREATE UNIQUE INDEX one_active_session_per_vehicle
ON public.parking_sessions (vehicle_id)
WHERE exit_time IS NULL;

CREATE UNIQUE INDEX one_active_session_per_slot
ON public.parking_sessions (slot_id)
WHERE exit_time IS NULL;

--VERIFYING TABLES--
/*
SELECT
    (SELECT COUNT(*) FROM public.profiles) AS total_profiles,
    (SELECT COUNT(*) FROM public.wedding_events) AS total_events,
    (SELECT COUNT(*) FROM public.vehicles) AS total_vehicles,
    (SELECT COUNT(*) FROM public.parking_slots) AS total_slots,
    (SELECT COUNT(*) FROM public.parking_sessions) AS total_sessions,
    (SELECT COUNT(*) FROM public.parking_events) AS total_audit_records;
*/