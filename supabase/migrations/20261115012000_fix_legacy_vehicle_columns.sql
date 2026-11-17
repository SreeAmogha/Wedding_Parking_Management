-- Compatibility repair for a legacy vehicles table used by the current app.
-- This only relaxes unused legacy fields and supplies a UUID default; it preserves rows.
DO $$
DECLARE legacy_column record;
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='vehicles'
          AND column_name='id' AND data_type='uuid'
    ) THEN
        ALTER TABLE public.vehicles ALTER COLUMN id SET DEFAULT gen_random_uuid();
    END IF;

    FOR legacy_column IN
        SELECT column_name FROM information_schema.columns
        WHERE table_schema='public' AND table_name='vehicles'
          AND column_name IN ('owner_id','vehicle_number','model','capacity')
    LOOP
        EXECUTE format('ALTER TABLE public.vehicles ALTER COLUMN %I DROP NOT NULL', legacy_column.column_name);
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
