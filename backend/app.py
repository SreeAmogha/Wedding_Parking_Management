import os
import re
from datetime import date
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, request, send_from_directory
from supabase import create_client


# -------------------- CONFIGURATION --------------------

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
FRONTEND_DIR = PROJECT_DIR / "frontend"

load_dotenv(BASE_DIR / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_PUBLISHABLE_KEY = os.getenv("SUPABASE_PUBLISHABLE_KEY")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY")

print("Supabase URL loaded:", repr(SUPABASE_URL))

if not all([
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY,
    SUPABASE_SECRET_KEY
]):
    raise RuntimeError(
        "Missing Supabase credentials. Check backend/.env"
    )

# Used to validate staff login tokens.
auth_client = create_client(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
)

# Server-side database client.
# Never expose this client's secret key to the browser.
db = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)

app = Flask(__name__)
@app.get("/")
def home():
    return send_from_directory(str(FRONTEND_DIR), "index.html")

# -------------------- COMMON HELPERS --------------------

def response_error(message, status_code=400):
    return jsonify({"error": message}), status_code


def get_staff():
    """Validate the Supabase login token and staff profile."""
    header = request.headers.get("Authorization", "")

    if not header.startswith("Bearer "):
        return None, None, response_error(
            "Please sign in first.", 401
        )

    token = header.split(" ", 1)[1].strip()

    try:
        result = auth_client.auth.get_user(token)
        user = result.user

        if not user:
            return None, None, response_error(
                "Invalid login session.", 401
            )

        profile_result = (
            db.table("profiles")
            .select("id, full_name, role")
            .eq("id", str(user.id))
            .single()
            .execute()
        )

        profile = profile_result.data

        if not profile:
            return None, None, response_error(
                "Staff profile not found.", 403
            )

        return user, profile, None

    except Exception as exc:
        print("STAFF AUTHENTICATION ERROR:", repr(exc))

    return None, None, response_error(
        "Your session is invalid or expired. Sign in again.",
        401
    )

def require_admin():
    user, profile, error = get_staff()

    if error:
        return None, None, error

    # FIXED: Allow both 'admin' and 'manager' roles
    if profile.get("role") not in ("admin", "manager"):
        return None, None, response_error(
            "Admin or Manager access required.",
            403
        )

    return user, profile, None


def require_staff():
    user, profile, error = get_staff()

    if error:
        return None, None, error

    return user, profile, None


def require_attendant():
    user, profile, error = require_staff()

    if error:
        return None, None, error

    # FIXED: Allow 'attendant', 'manager', and 'admin' roles for operations
    if profile.get("role") not in ("attendant", "manager", "admin"):
        return None, None, response_error(
            "Attendant or Manager access required.",
            403
        )

    return user, profile, None


def run_query(query):
    """Execute a Supabase query and return its data."""
    result = query.execute()
    return result.data


def first_row(data):
    if not data:
        return None
    if isinstance(data, list):
        return data[0] if data else None
    return data


def related_row(value):
    if isinstance(value, list):
        return value[0] if value else {}
    if isinstance(value, dict):
        return value
    return {}


def run_staff_rpc(name, params):
    """Call a database function as service role, then as the signed-in user."""
    try:
        return run_query(db.rpc(name, params))
    except Exception as exc:
        print(f"RPC {name} as service role failed:", repr(exc))

    header = request.headers.get("Authorization", "")
    token = header.split(" ", 1)[1].strip() if header.startswith("Bearer ") else ""
    staff_db = create_client(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY)
    if token:
        staff_db.postgrest.auth(token)

    fallback = {
        key: value
        for key, value in params.items()
        if key != "p_recorded_by"
    }
    return staff_db.rpc(name, fallback).execute().data


def refresh_event_statuses():
    """Keep persisted event statuses in sync with the database date."""
    for rpc_name in (
        "refresh_wedding_event_statuses",
        "update_wedding_event_statuses",
    ):
        try:
            run_query(db.rpc(rpc_name))
            return
        except Exception as exc:
            print(f"EVENT STATUS REFRESH ({rpc_name}):", repr(exc))


def find_auth_user_id_by_email(email):
    """Find an Auth user id by email across list_users pages."""
    email = (email or "").strip().lower()
    page = 1

    while page <= 20:
        try:
            result = db.auth.admin.list_users(page=page, per_page=200)
        except TypeError:
            result = db.auth.admin.list_users()

        users = result
        if isinstance(users, dict):
            users = users.get("users") or users.get("data") or []
        elif not isinstance(users, list):
            users = (
                getattr(result, "users", None)
                or getattr(result, "data", None)
                or []
            )

        for user in users:
            user_email = (getattr(user, "email", None) or "").lower()
            if user_email == email:
                return str(user.id)

        if len(users) < 200:
            return None

        page += 1

    return None


def ensure_demo_staff():
    """Create the extra attendant login used by the project demo."""
    demo_staff = (
        {
            "email": "attendant1@gmail.com",
            "password": "attendant1",
            "full_name": "Attendant 1",
            "role": "attendant",
        },
        {
            "email": "attendant2@gmail.com",
            "password": "attendant2",
            "full_name": "Attendant 2",
            "role": "attendant",
        },
    )

    for staff in demo_staff:
        user_id = None

        try:
            created = db.auth.admin.create_user(
                {
                    "email": staff["email"],
                    "password": staff["password"],
                    "email_confirm": True,
                }
            )
            user_id = str(created.user.id)
            print("Created demo staff user:", staff["email"])
        except Exception as exc:
            print("Demo staff create:", staff["email"], repr(exc))
            user_id = find_auth_user_id_by_email(staff["email"])
            if user_id:
                try:
                    db.auth.admin.update_user_by_id(
                        user_id,
                        {
                            "password": staff["password"],
                            "email_confirm": True,
                        },
                    )
                except Exception as update_exc:
                    print(
                        "Demo staff password update:",
                        staff["email"],
                        repr(update_exc),
                    )

        if not user_id:
            print("Could not resolve demo staff user:", staff["email"])
            continue

        try:
            db.table("profiles").upsert(
                {
                    "id": user_id,
                    "full_name": staff["full_name"],
                    "role": staff["role"],
                }
            ).execute()
            print("Ensured staff profile:", staff["email"], staff["role"])
        except Exception as exc:
            print("Demo staff profile error:", staff["email"], repr(exc))



# -------------------- FRONTEND --------------------

@app.get("/dashboard.html")
def dashboard_page():
    return send_from_directory(
        str(FRONTEND_DIR), "dashboard.html"
    )
@app.get("/history")
def parking_history_page():
    return send_from_directory(
        str(FRONTEND_DIR), "history.html"
    )
@app.get("/entry-exit")
def entry_exit_page():
    return send_from_directory(
        str(FRONTEND_DIR), "entry-exit.html"
    )

@app.get("/events")
def events_page():
    return send_from_directory(
        str(FRONTEND_DIR), "events.html"
    )


@app.get("/parking-slots")
def parking_slots_page():
    return redirect("/dashboard.html")


@app.get("/history.html")
def parking_history_html():
    return redirect("/history")


@app.get("/entry-exit.html")
def entry_exit_html():
    return redirect("/entry-exit")


@app.get("/events.html")
def events_html():
    return redirect("/events")
@app.get("/sidebar.js")
def sidebar_js():
    return send_from_directory(
        str(FRONTEND_DIR), "sidebar.js"
    )
@app.get("/style.css")
def stylesheet():
    return send_from_directory(
        str(FRONTEND_DIR), "style.css"
    )

@app.get("/app.js")
def frontend_app_js():
    return send_from_directory(
        str(FRONTEND_DIR), "app.js"
    )


# -------------------- STAFF PROFILE --------------------

@app.get("/api/profile")
def get_profile():
    _, profile, error = require_staff()

    if error:
        return error

    return jsonify({"profile": profile})


# -------------------- WEDDING EVENTS --------------------

@app.get("/api/events")
def get_events():
    _, _, error = require_staff()

    if error:
        return error

    try:
        refresh_event_statuses()
        events = run_query(
            db.table("wedding_events")
            .select("event_id, event_name, event_date, status")
            .order("event_date")
        )

        return jsonify({"events": events})

    except Exception as exc:
        print("EVENTS ERROR:", repr(exc))
        return response_error("Could not load events.", 500)


@app.post("/api/events")
def create_event():
    _, _, error = require_admin()

    if error:
        return error

    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return response_error("Event details must be a JSON object.", 400)

    event_name = data.get("event_name")
    event_date = data.get("event_date")
    if isinstance(event_name, str):
        event_name = event_name.strip()
    if isinstance(event_date, str):
        event_date = event_date.strip()

    if (
        not isinstance(event_name, str)
        or not event_name
        or not isinstance(event_date, str)
        or not event_date
    ):
        return response_error(
            "Event name and event date are required.",
            400
        )

    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", event_date):
        return response_error(
            "Event date must be a valid YYYY-MM-DD date.",
            400
        )

    try:
        parsed_date = date.fromisoformat(event_date)
    except ValueError:
        return response_error(
            "Event date must be a valid YYYY-MM-DD date.",
            400
        )

    try:
        result = run_query(
            db.table("wedding_events")
            .insert({
                "event_name": event_name,
                "event_date": parsed_date.isoformat()
            })
            .select("event_id, event_name, event_date, status")
        )
        created = first_row(result)
        if not created:
            return response_error("Could not create event.", 500)

        refresh_event_statuses()
        event = first_row(
            run_query(
                db.table("wedding_events")
                .select("event_id, event_name, event_date, status")
                .eq("event_id", created["event_id"])
                .limit(1)
            )
        ) or created

        return jsonify({
            "message": "Event created successfully.",
            "event": event
        }), 201

    except Exception as exc:
        print("CREATE EVENT ERROR:", repr(exc))
        return response_error("Could not create event.", 500)


# -------------------- PARKING DASHBOARD --------------------

@app.get("/api/slots")
def get_slots():
    _, _, error = require_staff()

    if error:
        return error

    try:
        slots = run_query(
            db.table("parking_slots")
            .select("slot_id, slot_number, status")
            .order("slot_number")
        )

        sessions = run_query(
            db.table("parking_sessions")
            .select(
                "slot_id, vehicles(registration_number)"
            )
            .is_("exit_time", "null")
        )

        vehicle_by_slot = {
            str(session["slot_id"]):
                related_row(session.get("vehicles")).get(
                    "registration_number", "Unknown"
                )
            for session in sessions
        }

        occupied_ids = set(vehicle_by_slot.keys())

        for slot in slots:
            slot_id = str(slot["slot_id"])
            occupied = slot_id in occupied_ids

            if slot["status"] == "unavailable":
                state = "unavailable"
            elif occupied:
                state = "occupied"
            else:
                state = "available"

            slot["display_status"] = state
            slot["registration_number"] = (
                vehicle_by_slot.get(slot_id)
            )

        available = sum(
            slot["display_status"] == "available"
            for slot in slots
        )

        occupied = sum(
            slot["display_status"] == "occupied"
            for slot in slots
        )

        return jsonify({
            "slots": slots,
            "total": len(slots),
            "available": available,
            "occupied": occupied
        })

    except Exception as exc:
        return response_error(str(exc), 500)


# -------------------- VEHICLE ENTRY --------------------

@app.post("/api/entry")
def register_entry():
    user, _, error = require_attendant()

    if error:
        return error

    body = request.get_json(silent=True) or {}

    registration = str(
        body.get("registration_number", "")
    ).strip().upper()

    vehicle_type = str(
        body.get("vehicle_type", "")
    ).strip().lower()

    guest_name = str(
        body.get("guest_name") or ""
    ).strip()

    guest_contact = str(
        body.get("guest_contact") or ""
    ).strip()

    try:
        event_id = int(body.get("event_id"))
    except (TypeError, ValueError):
        return response_error("Select a valid wedding event.")

    if not re.fullmatch(r"[A-Z0-9]{10}", registration):
        return response_error(
            "Vehicle registration must contain exactly "
            "10 letters or digits."
        )

    if vehicle_type not in {
        "car", "suv", "bike", "van", "other"
    }:
        return response_error("Select a valid vehicle type.")

    if guest_contact and not re.fullmatch(
        r"[0-9]{10}", guest_contact
    ):
        return response_error(
            "Contact number must contain exactly 10 digits."
        )

    try:
        refresh_event_statuses()
        event = first_row(
            run_query(
                db.table("wedding_events")
                .select("event_id, event_date, status")
                .eq("event_id", event_id)
                .limit(1)
            )
        )

        if not event:
            return response_error("Wedding event not found.", 404)

        if event["status"] != "active":
            return response_error(
                "Vehicle entry is allowed only for active events."
            )

        existing = first_row(
            run_query(
                db.table("vehicles")
                .select("vehicle_id")
                .eq("registration_number", registration)
                .limit(1)
            )
        )

        if existing:
            vehicle_id = existing["vehicle_id"]
        else:
            new_vehicle = first_row(
                run_query(
                    db.table("vehicles")
                    .insert({
                        "registration_number": registration,
                        "vehicle_type": vehicle_type,
                        "guest_name": guest_name or None,
                        "guest_contact": guest_contact or None
                    })
                    .select("vehicle_id")
                )
            )

            if not new_vehicle:
                return response_error("Could not register the vehicle.", 500)

            vehicle_id = new_vehicle["vehicle_id"]

        result = run_staff_rpc(
            "register_vehicle_entry",
            {
                "p_event_id": event_id,
                "p_vehicle_id": vehicle_id,
                "p_recorded_by": str(user.id)
            }
        )

        assigned = first_row(result)
        if not assigned or assigned.get("assigned_slot_number") is None:
            return response_error(
                "Entry failed: no parking slot was assigned.",
                400
            )

        return jsonify({
            "message": "Vehicle registered successfully.",
            "assigned_slot_number":
                assigned["assigned_slot_number"]
        }), 201

    except Exception as exc:
        import traceback
        traceback.print_exc()
        return response_error("Entry failed: " + str(exc), 400)


# -------------------- VEHICLE EXIT --------------------

@app.post("/api/exit")
def register_exit():
    user, _, error = require_attendant()

    if error:
        return error

    body = request.get_json(silent=True) or {}

    registration = str(
        body.get("registration_number", "")
    ).strip().upper()

    if not re.fullmatch(r"[A-Z0-9]{10}", registration):
        return response_error(
            "Enter a valid 10-character vehicle number."
        )

    try:
        result = run_staff_rpc(
            "register_vehicle_exit",
            {
                "p_registration_number": registration,
                "p_recorded_by": str(user.id)
            }
        )

        exited = first_row(result)
        if not exited or exited.get("freed_slot_number") is None:
            return response_error(
                "Exit failed: no active parking session was found.",
                400
            )

        return jsonify({
            "message": "Vehicle exit recorded successfully.",
            "freed_slot_number": exited["freed_slot_number"]
        })

    except Exception as exc:
        return response_error(
            "Exit failed: " + str(exc), 400
        )


# -------------------- PARKING HISTORY --------------------

@app.get("/api/history")
def get_history():
    _, _, error = require_staff()

    if error:
        return error

    try:
        event_id = int(request.args.get("event_id", ""))

        sessions = run_query(
            db.table("parking_sessions")
            .select("""
                entry_time,
                exit_time,
                vehicles(registration_number, guest_name),
                parking_slots(slot_number)
            """)
            .eq("event_id", event_id)
            .order("entry_time", desc=True)
        )

        for session in sessions or []:
            session["vehicles"] = related_row(session.get("vehicles"))
            session["parking_slots"] = related_row(session.get("parking_slots"))

        return jsonify({"sessions": sessions})

    except ValueError:
        return response_error("Select a valid wedding event.")

    except Exception as exc:
        return response_error(str(exc), 500)


# -------------------- START SERVER --------------------

if __name__ == "__main__":
    ensure_demo_staff()
    app.run(host="127.0.0.1", port=5000, debug=True)
