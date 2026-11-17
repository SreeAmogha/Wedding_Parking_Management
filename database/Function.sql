DROP FUNCTION IF EXISTS public.register_vehicle_entry(bigint,bigint);

-- Atomic entry registration. Backend calls provide p_recorded_by after validating the user's token;
-- direct authenticated RPC calls use auth.uid().
CREATE OR REPLACE FUNCTION public.register_vehicle_entry(
    p_event_id bigint,
    p_vehicle_id bigint,
    p_recorded_by uuid DEFAULT NULL
)
RETURNS TABLE (assigned_session_id bigint, assigned_slot_number integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_actor uuid;
    v_profile_id uuid;
    v_slot_id bigint;
    v_slot_number integer;
    v_session_id bigint;
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
    IF v_profile_id IS NULL THEN RAISE EXCEPTION 'Only signed-in staff can register vehicle entries.'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.wedding_events e WHERE e.event_id=p_event_id AND e.status='active') THEN
        RAISE EXCEPTION 'The wedding event does not exist or is not active.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.vehicles v WHERE v.vehicle_id=p_vehicle_id) THEN
        RAISE EXCEPTION 'Vehicle was not found.';
    END IF;
    SELECT ps.slot_id, ps.slot_number INTO v_slot_id, v_slot_number
    FROM public.parking_slots ps
    WHERE ps.status='available'
      AND NOT EXISTS (SELECT 1 FROM public.parking_sessions s WHERE s.slot_id=ps.slot_id AND s.exit_time IS NULL)
    ORDER BY ps.slot_number LIMIT 1 FOR UPDATE OF ps SKIP LOCKED;
    IF v_slot_id IS NULL THEN RAISE EXCEPTION 'No parking slots are currently available.'; END IF;
    INSERT INTO public.parking_sessions(event_id, vehicle_id, slot_id, entry_recorded_by)
    VALUES (p_event_id, p_vehicle_id, v_slot_id, v_profile_id)
    RETURNING session_id INTO v_session_id;
    INSERT INTO public.parking_events(session_id, action_type, performed_by, notes)
    VALUES (v_session_id, 'entry', v_profile_id, 'Vehicle entry registered; slot ' || v_slot_number::text || ' assigned.');
    RETURN QUERY SELECT v_session_id, v_slot_number;
END $$;
REVOKE ALL ON FUNCTION public.register_vehicle_entry(bigint,bigint,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_vehicle_entry(bigint,bigint,uuid) TO authenticated, service_role;
