INSERT INTO public.parking_slots (slot_number)
SELECT generate_series(1, 50);
