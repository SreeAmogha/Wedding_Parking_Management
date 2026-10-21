
--SAFE GUARDS?--
CREATE UNIQUE INDEX one_active_session_per_vehicle
ON public.parking_sessions (vehicle_id)
WHERE exit_time IS NULL;

CREATE UNIQUE INDEX one_active_session_per_slot
ON public.parking_sessions (slot_id)
WHERE exit_time IS NULL;

SELECT
    tablename,
    rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
      'profiles',
      'wedding_events',
      'vehicles',
      'parking_slots',
      'parking_sessions',
      'parking_events'
  )
ORDER BY tablename;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'parking_sessions'
  AND indexname IN (
      'one_active_session_per_vehicle',
      'one_active_session_per_slot'
  )
ORDER BY indexname;

CREATE POLICY "Staff can read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (id = (SELECT auth.uid()));

CREATE POLICY "Staff can view wedding events"
ON public.wedding_events
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE profiles.id = (SELECT auth.uid())
    )
);

CREATE POLICY "Staff can view vehicles"
ON public.vehicles
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE profiles.id = (SELECT auth.uid())
    )
);

CREATE POLICY "Staff can view parking slots"
ON public.parking_slots
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE profiles.id = (SELECT auth.uid())
    )
);


CREATE POLICY "Staff can view parking sessions"
ON public.parking_sessions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE profiles.id = (SELECT auth.uid())
    )
);
