DROP FUNCTION IF EXISTS public.register_vehicle_entry(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS public.register_vehicle_entry(BIGINT, BIGINT, UUID);

CREATE OR REPLACE FUNCTION public.register_vehicle_entry(
    p_event_id BIGINT,
    p_vehicle_id BIGINT,
    p_recorded_by UUID DEFAULT NULL
)
RETURNS TABLE (
    assigned_session_id BIGINT,
    assigned_slot_number INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_slot_id BIGINT;
    v_slot_number INTEGER;
    v_session_id BIGINT;
BEGIN
    v_user_id := COALESCE(p_recorded_by, auth.uid());

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be logged in.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = v_user_id
          AND p.role IN ('attendant', 'manager', 'admin')
    ) THEN
        RAISE EXCEPTION 'Only staff can register vehicle entries.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.wedding_events e
        WHERE e.event_id = p_event_id
          AND e.status = 'active'
    ) THEN
        RAISE EXCEPTION 'The wedding event does not exist or is not active.';
    END IF;

    SELECT ps.slot_id, ps.slot_number
    INTO v_slot_id, v_slot_number
    FROM public.parking_slots ps
    WHERE ps.status = 'available'
      AND NOT EXISTS (
          SELECT 1
          FROM public.parking_sessions s
          WHERE s.slot_id = ps.slot_id
            AND s.exit_time IS NULL
      )
    ORDER BY ps.slot_number
    LIMIT 1
    FOR UPDATE OF ps SKIP LOCKED;

    IF v_slot_id IS NULL THEN
        RAISE EXCEPTION 'No parking slots are currently available.';
    END IF;

    INSERT INTO public.parking_sessions (
        event_id,
        vehicle_id,
        slot_id,
        entry_recorded_by
    )
    VALUES (
        p_event_id,
        p_vehicle_id,
        v_slot_id,
        v_user_id
    )
    RETURNING session_id INTO v_session_id;

    INSERT INTO public.parking_events (
        session_id,
        action_type,
        performed_by,
        notes
    )
    VALUES (
        v_session_id,
        'entry',
        v_user_id,
        'Vehicle entry registered; slot '
            || v_slot_number::TEXT || ' assigned.'
    );

    RETURN QUERY
    SELECT v_session_id, v_slot_number;
END;
$$;

REVOKE ALL ON FUNCTION
    public.register_vehicle_entry(BIGINT, BIGINT, UUID)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.register_vehicle_entry(BIGINT, BIGINT, UUID)
TO authenticated, service_role;
