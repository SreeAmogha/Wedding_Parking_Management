-- Local seed data: parking capacity only; no fake auth users or sample events.
INSERT INTO public.parking_slots (slot_number)
SELECT generate_series(1, 50)
ON CONFLICT (slot_number) DO NOTHING;
