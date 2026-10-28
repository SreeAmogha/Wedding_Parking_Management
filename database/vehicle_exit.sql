DROP FUNCTION IF EXISTS public.register_vehicle_exit(TEXT);
DROP FUNCTION IF EXISTS public.register_vehicle_exit(TEXT, UUID);

CREATE OR REPLACE FUNCTION public.register_vehicle_exit(
    p_registration_number TEXT,
    p_recorded_by UUID DEFAULT NULL
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
        RAISE EXCEPTION 'Only staff can register vehicle exits.';
    END IF;

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

    UPDATE public.parking_sessions
    SET exit_time = NOW(),
        exit_recorded_by = v_user_id
    WHERE session_id = v_session_id;

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

    RETURN QUERY
    SELECT v_session_id, v_slot_number;
END;
$$;

REVOKE ALL ON FUNCTION
    public.register_vehicle_exit(TEXT, UUID)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
    public.register_vehicle_exit(TEXT, UUID)
TO authenticated, service_role;
