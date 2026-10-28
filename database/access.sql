/*
SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
      'profiles',
      'wedding_events',
      'vehicles',
      'parking_slots',
      'parking_sessions',
      'parking_events'
  )
  AND grantee IN ('anon', 'authenticated')
ORDER BY table_name, grantee, privilege_type;


REVOKE ALL PRIVILEGES ON TABLE
    public.profiles,
    public.wedding_events,
    public.vehicles,
    public.parking_slots,
    public.parking_sessions,
    public.parking_events
FROM anon, authenticated;

GRANT SELECT ON TABLE
    public.profiles,
    public.wedding_events,
    public.vehicles,
    public.parking_slots,
    public.parking_sessions,
    public.parking_events
TO authenticated;

GRANT INSERT ON TABLE public.vehicles
TO authenticated;


SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
      'profiles',
      'wedding_events',
      'vehicles',
      'parking_slots',
      'parking_sessions',
      'parking_events'
  )
  AND grantee IN ('anon', 'authenticated')
ORDER BY table_name, grantee, privilege_type;
*/
GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE
    public.profiles,
    public.wedding_events,
    public.parking_slots,
    public.vehicles,
    public.parking_sessions
TO service_role;

-- 1. Allow the backend to access the public schema
GRANT USAGE ON SCHEMA public TO service_role;

-- 2. Grant access to all existing tables and views
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO service_role;

-- 3. Grant access to sequences used by inserts
GRANT USAGE, SELECT, UPDATE
ON ALL SEQUENCES IN SCHEMA public
TO service_role;

-- 4. Allow the backend to execute all existing functions
-- This includes register_vehicle_entry and register_vehicle_exit
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public
TO service_role;

-- 5. Allow execution of existing procedures, if any
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA public
TO service_role;

-- 6. Set default permissions for future tables and sequences
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO service_role;

-- 7. Set default permissions for future functions
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO service_role;
