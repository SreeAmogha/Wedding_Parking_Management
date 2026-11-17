/*INSERT INTO public.profiles (id, full_name, role)
VALUES (
    '75fa6464-59cc-4cf2-a604-f3b56b629fa7',
    'Admin',
    'admin'
);
SELECT id, full_name, role
FROM public.profiles
WHERE role = 'admin';

SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
      'refresh_wedding_event_statuses',
      'update_wedding_event_statuses'
  );
  SELECT
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public';
SELECT
    event_name,
    event_date,
    COUNT(*) AS duplicate_count,
    ARRAY_AGG(event_id ORDER BY created_at) AS event_ids
FROM public.wedding_events
GROUP BY event_name, event_date
HAVING COUNT(*) > 1
ORDER BY event_name;
SELECT
    event_id,
    event_name,
    event_date,
    status,
    created_at
FROM public.wedding_events
WHERE (event_name, event_date) IN (
    SELECT event_name, event_date
    FROM public.wedding_events
    GROUP BY event_name, event_date
    HAVING COUNT(*) > 1
)
ORDER BY event_name, event_date, created_at;*/
WITH ranked_events AS (
    SELECT
        event_id,
        event_name,
        event_date,
        ROW_NUMBER() OVER (
            PARTITION BY event_name, event_date
            ORDER BY created_at ASC, event_id ASC
        ) AS rn
    FROM public.wedding_events
)
DELETE FROM public.wedding_events AS e
USING ranked_events AS r
WHERE e.event_id = r.event_id
  AND r.rn > 1
  AND NOT EXISTS (
      SELECT 1
      FROM public.parking_sessions AS ps
      WHERE ps.event_id = e.event_id
  )
RETURNING e.event_id, e.event_name, e.event_date;