-- Seed 50 reusable parking spaces. Re-running does not duplicate slots.
INSERT INTO public.parking_slots (slot_number)
SELECT generate_series(1, 50)
ON CONFLICT (slot_number) DO NOTHING;
