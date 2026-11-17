# Smart Wedding Parking

## Supabase configuration

The browser client in `frontend/app.js` uses the Supabase URL and publishable key. The server loads `backend/.env`; keep its secret key private and never commit it. The backend secret must be a Supabase secret/service-role key for the same project as the URL and browser publishable key.

Create `backend/.env` with:

```text
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<your-project-publishable-key>
SUPABASE_SECRET_KEY=<your-project-secret-key>
```

The repo ignores `backend/.env`. The frontend publishable key is public by design; never place the secret key in frontend files.

## Database setup

The app uses `profiles`, `wedding_events`, `vehicles`, `parking_slots`, `parking_sessions`, and `parking_events`. In the Supabase SQL Editor, either run the single consolidated file `supabase/migrations/20261115010000_wedding_parking_app.sql`, or run these component files in order:

1. `database/01_create_tables.sql`
2. `database/02_insert_parking_slots.sql`
3. `database/03_parking_constraints.sql`
4. `database/Function.sql`
5. `database/vehicle_exit.sql`
6. `database/04_event_status_and_access.sql`

These scripts are idempotent and preserve existing rows. If the earlier schema migration was already run before the legacy-vehicle fix, run `database/06_fix_legacy_vehicle_columns.sql` once in the SQL Editor. `database/remote_dump.sql` is only a partial metadata export and must not be used to initialize or restore a project. `database/05_fix_event_access_and_status.sql`, `database/GRANT_PERMISSIONS.sql`, and `database/access.sql` are compatibility/deprecation stubs; do not run legacy broad-access scripts. The `supabase/migrations` directory has a single current app-schema migration; older migrations are retained as no-ops to prevent destructive or incompatible setup steps.

The schema script configures staff-only RLS, grants backend access to the server key, and keeps profile IDs compatible with Supabase Auth. New Auth users receive a `pending` profile and cannot use staff features until explicitly assigned a role. Create users through **Authentication → Users**, then run `UPDATE public.profiles SET role = 'attendant' WHERE auth_uid = '<auth-user-uuid>';` or set `role = 'admin'` for an administrator. Do not use default/demo passwords.

## Run locally

Install dependencies with `python3 -m pip install -r requirements.txt`, then run:

```bash
python3 backend/app.py
```

Open `http://127.0.0.1:5000`. An event must be `active` to accept vehicle entries. Planned events dated today are activated automatically when the event list is loaded; past events become completed. Parking history is available by selecting an event on the History page.
