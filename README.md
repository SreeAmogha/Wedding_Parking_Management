# Smart Wedding Parking setup

## Supabase configuration

The browser client in `frontend/app.js` uses the project's URL and publishable
(or legacy `anon`) key. Confirm these match **Project Settings → API Keys** for
the configured project. This key is intended for browser use; never put the
`service_role`/secret key in frontend code.

Create `backend/.env` with these values before starting the Flask app:

```text
SUPABASE_URL=https://szjprsarixeeqkcqfush.supabase.co
SUPABASE_PUBLISHABLE_KEY=<project-publishable-key>
SUPABASE_SECRET_KEY=<project-secret-or-service-role-key>
```

The backend secret key is used only by Flask and must not be shared or committed.

In the Supabase SQL Editor, run the database scripts in order:

1. `database/01_create_tables.sql`
2. `database/02_insert_parking_slots.sql`
3. `database/03_parking_constraints.sql`
4. `database/04_event_status_and_access.sql`

The last script installs/configures `pg_cron`, enables staff data access policies,
and schedules event status refresh at midnight in pg_cron's configured timezone.
Enable the `pg_cron` extension for the project first if Supabase reports it is
unavailable. The backend also refreshes statuses when events are listed or a
vehicle entry is attempted, so entries use the current database date even if
the scheduled task has not run yet. Configure the cron and database session
timezones consistently with the timezone in which event dates should change
from planned to active.

## Create an administrator

Create a user from **Authentication → Users → Add user** (or invite them), then
copy that user's UUID. In the SQL Editor, grant the profile its admin role:

```sql
INSERT INTO public.profiles (id, full_name, role)
VALUES ('<auth-user-uuid>', '<administrator-name>', 'admin')
ON CONFLICT (id) DO UPDATE
SET full_name = EXCLUDED.full_name, role = 'admin';
```

Create attendants the same way, using the `attendant` role. Profiles cannot be
created or promoted from the browser; this prevents users from granting
themselves administrator access. The admin role sees the dashboard, event
management, and parking history. Attendants see the dashboard, entry/exit, and
parking history. Event creation is checked by both the Flask API and Supabase
row-level security.

## Run locally

From the repository root, start the backend with:

```powershell
python backend\app.py
```

Then open `http://127.0.0.1:5000`. Vehicle entry is available only for an event
whose date is today in the configured database timezone; event status is
`planned` before that date and `completed` after it.