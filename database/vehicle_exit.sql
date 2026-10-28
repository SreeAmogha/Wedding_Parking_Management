
CREATE OR REPLACE FUNCTION public.register_vehicle_exit(
    p_registration_number TEXT
)
RETURNS TABLE (
    completed_session_id BIGINT,
    freed_slot_number INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
    v_session_id BIGINT;
    v_slot_id BIGINT;
    v_slot_number INTEGER;
BEGIN
    -- Verify that the user is logged in
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'You must be logged in.';
    END IF;

    -- Only attendants can record exits
    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = v_user_id
          AND p.role = 'attendant'
    ) THEN
        RAISE EXCEPTION 'Only attendants can register vehicle exits.';
    END IF;

    -- Find the vehicle's active parking session and lock it
    SELECT s.session_id, s.slot_id, ps.slot_number
    INTO v_session_id, v_slot_id, v_slot_number
    FROM public.parking_sessions s
    JOIN public.vehicles v
        ON v.vehicle_id = s.vehicle_id
    JOIN public.parking_slots ps
        ON ps.slot_id = s.slot_id
    WHERE UPPER(v.registration_number) = UPPER(TRIM(p_registration_number))
      AND s.exit_time IS NULL
    FOR UPDATE OF s;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'No active parking session found for this vehicle.';
    END IF;

    -- Record the vehicle's exit
    UPDATE public.parking_sessions
    SET exit_time = NOW(),
        exit_recorded_by = v_user_id
    WHERE session_id = v_session_id;

    -- Add an immutable-style audit record
    INSERT INTO public.parking_events (
        session_id,
        action_type,
        performed_by,
        notes
    )
    VALUES (
        v_session_id,
        'exit',
        v_user_id,
        'Vehicle exited; slot '
            || v_slot_number::TEXT || ' released.'
    );

    -- Return the completed session and released slot
    RETURN QUERY
    SELECT v_session_id, v_slot_number;
END;
$$;

REVOKE ALL ON FUNCTION
    public.register_vehicle_exit(TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.register_vehicle_exit(TEXT)
TO authenticated;
