
INSERT INTO public.vehicles (
    registration_number,
    vehicle_type,
    guest_name,
    guest_contact
)
VALUES (
    'KA01AB1234',
    'car',
    'Test Guest',
    NULL
)
RETURNING vehicle_id, registration_number, vehicle_type;
