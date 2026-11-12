-- ============================================================================
-- RUN THIS ENTIRE SCRIPT IN YOUR SUPABASE SQL EDITOR
-- Link: https://supabase.com/dashboard/project/szjprsarixeeqkcqfush/sql
-- ============================================================================

-- 1. Grant table-level permissions to authenticated users
GRANT ALL ON TABLE public.wedding_events TO authenticated;
GRANT ALL ON TABLE public.vehicles TO authenticated;
GRANT ALL ON TABLE public.parking_sessions TO authenticated;
GRANT ALL ON TABLE public.parking_slots TO authenticated;
GRANT ALL ON TABLE public.parking_events TO authenticated;
GRANT ALL ON TABLE public.profiles TO authenticated;

-- 2. Grant permissions on all sequences (needed for auto-increment IDs like event_id, vehicle_id)
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 3. Grant execute on stored functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- 4. Enable Row Level Security (RLS) and grant permissive access to authenticated staff
ALTER TABLE public.wedding_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wedding_events_read_all" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_staff_read" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_staff_read" ON public.wedding_events;
CREATE POLICY "wedding_events_read_all"
ON public.wedding_events FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "wedding_events_staff_insert" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_admin_insert" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_admin_insert" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_staff_insert" ON public.wedding_events;
CREATE POLICY "wedding_events_staff_insert"
ON public.wedding_events FOR INSERT TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "wedding_events_staff_update" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_admin_update" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_admin_update" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_staff_update" ON public.wedding_events;
CREATE POLICY "wedding_events_staff_update"
ON public.wedding_events FOR UPDATE TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "wedding_events_staff_delete" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_admin_delete" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_admin_delete" ON public.wedding_events;
DROP POLICY IF EXISTS "wedding_events_restrict_staff_delete" ON public.wedding_events;
CREATE POLICY "wedding_events_staff_delete"
ON public.wedding_events FOR DELETE TO authenticated
USING (true);

-- 5. Policies for vehicles and parking sessions (for entry/exit registration)
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vehicles_all_access" ON public.vehicles;
CREATE POLICY "vehicles_all_access"
ON public.vehicles FOR ALL TO authenticated
USING (true)
WITH CHECK (true);

ALTER TABLE public.parking_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "parking_sessions_all_access" ON public.parking_sessions;
CREATE POLICY "parking_sessions_all_access"
ON public.parking_sessions FOR ALL TO authenticated
USING (true)
WITH CHECK (true);

-- 6. Refresh function: auto-activates today's planned events and auto-completes past events
CREATE OR REPLACE FUNCTION public.refresh_wedding_event_statuses()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    UPDATE public.wedding_events
    SET status = 'active'
    WHERE event_date = CURRENT_DATE
      AND status = 'planned';

    UPDATE public.wedding_events
    SET status = 'completed'
    WHERE event_date < CURRENT_DATE
      AND status != 'completed';
$$;

GRANT EXECUTE ON FUNCTION public.refresh_wedding_event_statuses() TO authenticated, service_role;

-- Run it now to verify
SELECT public.refresh_wedding_event_statuses();

-- Check current events
SELECT event_id, event_name, event_date, status FROM public.wedding_events ORDER BY event_date DESC;
