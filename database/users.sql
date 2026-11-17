/*
INSERT INTO public.profiles (id, full_name, role)
VALUES (
    'dcb3b51a-b129-4c57-b769-691ee933447a'::UUID,
    'Name',
    'attendant'
);

-- Demo attendants are created from the Flask app on startup:
-- attendant1@gmail.com / attendant1
-- attendant2@gmail.com / attendant2
*/
SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_rule
FROM pg_constraint
WHERE conrelid = 'public.wedding_events'::regclass
  AND contype = 'c';