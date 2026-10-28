
CREATE OR REPLACE FUNCTION public.register_vehicle_entry(
    p_event_id BIGINT,
    p_vehicle_id BIGINT
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
    -- 1. Check login
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be logged in.';
    END IF;

    -- 2. Verify attendant role
    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = v_user_id
          AND p.role = 'attendant'
    ) THEN
        RAISE EXCEPTION 'Only attendants can register vehicle entries.';
    END IF;

    -- 3. Verify wedding event is active
    IF NOT EXISTS (
        SELECT 1
        FROM public.wedding_events e
        WHERE e.event_id = p_event_id
          AND e.status = 'active'
    ) THEN
        RAISE EXCEPTION 'The wedding event does not exist or is not active.';
    END IF;

    -- 4. Find and lock a free, usable parking slot
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

    -- 5. Create the parking session
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

    -- 6. Record the entry in the audit log
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

    -- 7. Return the assigned session and slot
    RETURN QUERY
    SELECT v_session_id, v_slot_number;
END;
$$;

-- Restrict function execution to authenticated users
REVOKE ALL ON FUNCTION
    public.register_vehicle_entry(BIGINT, BIGINT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.register_vehicle_entry(BIGINT, BIGINT)
TO authenticated;
