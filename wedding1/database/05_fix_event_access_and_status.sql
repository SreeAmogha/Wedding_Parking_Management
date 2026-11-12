-- ============================================================================
-- FIX: EVENT ACCESS & STATUS SYNCHRONIZATION
-- Run this script in your Supabase SQL Editor
-- ============================================================================

-- 1. Refresh Event Statuses Function:
-- Auto-activates today's planned events and auto-completes past events.
-- Does NOT demote manually activated events to planned!
CREATE OR REPLACE FUNCTION public.refresh_wedding_event_statuses()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    -- Auto-activate today's planned events
    UPDATE public.wedding_events
    SET status = 'active'
    WHERE event_date = CURRENT_DATE
      AND status = 'planned';

    -- Auto-complete past events
    UPDATE public.wedding_events
    SET status = 'completed'
    WHERE event_date < CURRENT_DATE
      AND status != 'completed';
$$;

REVOKE ALL ON FUNCTION public.refresh_wedding_event_statuses() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.refresh_wedding_event_statuses() TO authenticated, service_role;

-- 2. Allow all staff (attendant, manager, admin) to read wedding events
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

-- 3. Allow all staff (attendant, manager, admin) to create/insert wedding events
DROP POLICY IF EXISTS wedding_events_admin_insert ON public.wedding_events;
DROP POLICY IF EXISTS wedding_events_staff_insert ON public.wedding_events;
CREATE POLICY wedding_events_staff_insert
    ON public.wedding_events FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

DROP POLICY IF EXISTS wedding_events_restrict_admin_insert ON public.wedding_events;
DROP POLICY IF EXISTS wedding_events_restrict_staff_insert ON public.wedding_events;
CREATE POLICY wedding_events_restrict_staff_insert
    ON public.wedding_events AS RESTRICTIVE FOR INSERT TO public
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

-- 4. Allow all staff (attendant, manager, admin) to update wedding events
DROP POLICY IF EXISTS wedding_events_admin_update ON public.wedding_events;
DROP POLICY IF EXISTS wedding_events_staff_update ON public.wedding_events;
CREATE POLICY wedding_events_staff_update
    ON public.wedding_events FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

DROP POLICY IF EXISTS wedding_events_restrict_admin_update ON public.wedding_events;
DROP POLICY IF EXISTS wedding_events_restrict_staff_update ON public.wedding_events;
CREATE POLICY wedding_events_restrict_staff_update
    ON public.wedding_events AS RESTRICTIVE FOR UPDATE TO public
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = (SELECT auth.uid())
              AND p.role IN ('admin', 'manager', 'attendant')
        )
    );

-- 5. Run the status refresh now
SELECT public.refresh_wedding_event_statuses();

-- 6. Ensure there is at least one active wedding event for today
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.wedding_events WHERE status = 'active'
    ) THEN
        -- If an event exists for today, make it active
        IF EXISTS (SELECT 1 FROM public.wedding_events WHERE event_date = CURRENT_DATE) THEN
            UPDATE public.wedding_events
            SET status = 'active'
            WHERE event_date = CURRENT_DATE;
        ELSE
            -- Otherwise create a default active event for today
            INSERT INTO public.wedding_events (event_name, event_date, status)
            VALUES ('Grand Wedding Reception', CURRENT_DATE, 'active');
        END IF;
    END IF;
END;
$$;
