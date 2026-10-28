/*CREATE OR REPLACE FUNCTION public.update_wedding_event_statuses()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.wedding_events
    SET status = CASE
        WHEN event_date > CURRENT_DATE THEN 'planned'
        WHEN event_date = CURRENT_DATE THEN 'active'
        ELSE 'completed'
    END
    WHERE status IS DISTINCT FROM
        CASE
            WHEN event_date > CURRENT_DATE THEN 'planned'
            WHEN event_date = CURRENT_DATE THEN 'active'
            ELSE 'completed'
        END;
$$;
SELECT cron.schedule(
    'update-wedding-event-statuses-daily',
    '30 18 * * *',
    $$SELECT public.update_wedding_event_statuses();$$
);
SELECT jobid, jobname, schedule, command
FROM cron.job;

SELECT public.update_wedding_event_statuses();
*/
SELECT event_id, event_name, event_date, status
FROM public.wedding_events
ORDER BY event_date;