CREATE OR REPLACE FUNCTION public.refresh_wedding_event_statuses()
RETURNS void
LANGUAGE sql
AS $$
    UPDATE public.wedding_events
    SET status = CASE
        WHEN event_date < CURRENT_DATE THEN 'completed'
        WHEN event_date = CURRENT_DATE THEN 'active'
        ELSE 'planned'
    END
    WHERE status IS DISTINCT FROM CASE
        WHEN event_date < CURRENT_DATE THEN 'completed'
        WHEN event_date = CURRENT_DATE THEN 'active'
        ELSE 'planned'
    END;
$$;

REVOKE ALL ON FUNCTION public.refresh_wedding_event_statuses() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_wedding_event_statuses() TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
DECLARE
    existing_job_id bigint;
BEGIN
    FOR existing_job_id IN
        SELECT jobid
        FROM cron.job
        WHERE jobname = 'refresh-wedding-event-statuses'
    LOOP
        PERFORM cron.unschedule(existing_job_id);
    END LOOP;

    PERFORM cron.schedule(
        'refresh-wedding-event-statuses',
        '0 0 * * *',
        'SELECT public.refresh_wedding_event_statuses()'
    );
END;
$$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wedding_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parking_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_read_own ON public.profiles;
CREATE POLICY profiles_read_own
    ON public.profiles FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));
DROP POLICY IF EXISTS profiles_restrict_read_own ON public.profiles;
CREATE POLICY profiles_restrict_read_own
    ON public.profiles AS RESTRICTIVE FOR SELECT TO public
    USING (id = (SELECT auth.uid()));
DROP POLICY IF EXISTS profiles_restrict_client_insert ON public.profiles;
CREATE POLICY profiles_restrict_client_insert
    ON public.profiles AS RESTRICTIVE FOR INSERT TO public
    WITH CHECK (false);
DROP POLICY IF EXISTS profiles_restrict_client_update ON public.profiles;
CREATE POLICY profiles_restrict_client_update
    ON public.profiles AS RESTRICTIVE FOR UPDATE TO public
    USING (false) WITH CHECK (false);
DROP POLICY IF EXISTS profiles_restrict_client_delete ON public.profiles;
CREATE POLICY profiles_restrict_client_delete
    ON public.profiles AS RESTRICTIVE FOR DELETE TO public
    USING (false);

-- UPDATED: Added 'manager' to staff read policies
DROP POLICY IF EXISTS wedding_events_staff_read ON public.wedding_events;
CREATE POLICY wedding_events_staff_read
    ON public.wedding_events FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );
DROP POLICY IF EXISTS wedding_events_restrict_staff_read ON public.wedding_events;
CREATE POLICY wedding_events_restrict_staff_read
    ON public.wedding_events AS RESTRICTIVE FOR SELECT TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

-- UPDATED: Allowed 'manager' alongside 'admin' for event inserts/updates/deletes
DROP POLICY IF EXISTS wedding_events_admin_insert ON public.wedding_events;
CREATE POLICY wedding_events_admin_insert
    ON public.wedding_events FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );
DROP POLICY IF EXISTS wedding_events_restrict_admin_insert ON public.wedding_events;
CREATE POLICY wedding_events_restrict_admin_insert
    ON public.wedding_events AS RESTRICTIVE FOR INSERT TO public
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );
DROP POLICY IF EXISTS wedding_events_admin_update ON public.wedding_events;
CREATE POLICY wedding_events_admin_update
    ON public.wedding_events FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );
DROP POLICY IF EXISTS wedding_events_restrict_admin_update ON public.wedding_events;
CREATE POLICY wedding_events_restrict_admin_update
    ON public.wedding_events AS RESTRICTIVE FOR UPDATE TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );
DROP POLICY IF EXISTS wedding_events_admin_delete ON public.wedding_events;
CREATE POLICY wedding_events_admin_delete
    ON public.wedding_events FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );
DROP POLICY IF EXISTS wedding_events_restrict_admin_delete ON public.wedding_events;
CREATE POLICY wedding_events_restrict_admin_delete
    ON public.wedding_events AS RESTRICTIVE FOR DELETE TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid()) AND p.role IN ('admin', 'manager')
        )
    );

-- UPDATED: Added 'manager' to parking slots read policies
DROP POLICY IF EXISTS parking_slots_staff_read ON public.parking_slots;
CREATE POLICY parking_slots_staff_read
    ON public.parking_slots FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );
DROP POLICY IF EXISTS parking_slots_restrict_staff_read ON public.parking_slots;
CREATE POLICY parking_slots_restrict_staff_read
    ON public.parking_slots AS RESTRICTIVE FOR SELECT TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

-- UPDATED: Added 'manager' to vehicles read policies
DROP POLICY IF EXISTS vehicles_staff_read ON public.vehicles;
CREATE POLICY vehicles_staff_read
    ON public.vehicles FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );
DROP POLICY IF EXISTS vehicles_restrict_staff_read ON public.vehicles;
CREATE POLICY vehicles_restrict_staff_read
    ON public.vehicles AS RESTRICTIVE FOR SELECT TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

-- UPDATED: Added 'manager' to parking sessions read policies
DROP POLICY IF EXISTS parking_sessions_staff_read ON public.parking_sessions;
CREATE POLICY parking_sessions_staff_read
    ON public.parking_sessions FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );
DROP POLICY IF EXISTS parking_sessions_restrict_staff_read ON public.parking_sessions;
CREATE POLICY parking_sessions_restrict_staff_read
    ON public.parking_sessions AS RESTRICTIVE FOR SELECT TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );