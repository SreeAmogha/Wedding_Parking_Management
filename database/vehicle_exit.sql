DROP FUNCTION IF EXISTS public.register_vehicle_exit(text);

-- Atomic vehicle exit registration.
CREATE OR REPLACE FUNCTION public.register_vehicle_exit(
    p_registration_number text,
    p_recorded_by uuid DEFAULT NULL
)
RETURNS TABLE (completed_session_id bigint, freed_slot_number integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_actor uuid;
    v_profile_id uuid;
    v_session_id bigint;
    v_slot_id bigint;
    v_slot_number integer;
BEGIN
    -- A browser-authenticated caller can only act as its own user; the server passes
    -- p_recorded_by only after validating the bearer token.
    IF (SELECT auth.uid()) IS NOT NULL THEN
        v_actor := (SELECT auth.uid());
    ELSE
        v_actor := p_recorded_by;
    END IF;
    SELECT p.id INTO v_profile_id
    FROM public.profiles p
    WHERE (p.id=v_actor OR p.auth_uid=v_actor)
      AND p.role IN ('admin','manager','attendant')
    LIMIT 1;
    IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Only signed-in staff can register vehicle exits.'; END IF;
    SELECT s.session_id, s.slot_id, ps.slot_number INTO v_session_id, v_slot_id, v_slot_number
    FROM public.parking_sessions s
    JOIN public.vehicles v ON v.vehicle_id=s.vehicle_id
    JOIN public.parking_slots ps ON ps.slot_id=s.slot_id
    WHERE upper(v.registration_number)=upper(trim(p_registration_number)) AND s.exit_time IS NULL
    FOR UPDATE OF s;
    IF v_session_id IS NULL THEN RAISE EXCEPTION 'No active parking session found for this vehicle.'; END IF;
    UPDATE public.parking_sessions SET exit_time=now(), exit_recorded_by=v_profile_id
    WHERE session_id=v_session_id;
    INSERT INTO public.parking_events(session_id, action_type, performed_by, notes)
    VALUES (v_session_id, 'exit', v_profile_id, 'Vehicle exited; slot ' || v_slot_number::text || ' released.');
    RETURN QUERY SELECT v_session_id, v_slot_number;
END $$;
REVOKE ALL ON FUNCTION public.register_vehicle_exit(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_vehicle_exit(text,uuid) TO authenticated, service_role;
