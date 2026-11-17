-- Status transitions happen when events are listed/entries are attempted; no pg_cron extension required.
-- Manually activated future events remain active; past events become completed.
CREATE OR REPLACE FUNCTION public.refresh_wedding_event_statuses()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    UPDATE public.wedding_events SET status='completed'
    WHERE event_date < CURRENT_DATE AND status <> 'completed';
    UPDATE public.wedding_events SET status='active'
    WHERE event_date = CURRENT_DATE AND status='planned';
END $$;
REVOKE ALL ON FUNCTION public.refresh_wedding_event_statuses() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_wedding_event_statuses() TO service_role;
