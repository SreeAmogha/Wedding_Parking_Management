
INSERT INTO public.wedding_events (
    event_name,
    event_date,
    status
)
VALUES (
    'Demo Wedding',
    CURRENT_DATE,
    'active'
)
RETURNING event_id, event_name, event_date, status;
