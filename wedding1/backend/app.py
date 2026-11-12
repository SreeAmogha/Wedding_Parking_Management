import datetime
import os
import re
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_from_directory
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


def require_staff():
    user, profile, error = get_staff()

    if error:
        return None, None, error

    return user, profile, None


def run_query(query):
    """Execute a Supabase query and return its data."""
    result = query.execute()
    return result.data


# -------------------- FRONTEND STATIC ROUTES --------------------

@app.get("/")
def home():
    return send_from_directory(str(FRONTEND_DIR), "index.html")

@app.get("/dashboard")
@app.get("/dashboard.html")
def dashboard_page():
    return send_from_directory(str(FRONTEND_DIR), "dashboard.html")

@app.get("/entry-exit")
@app.get("/entry-exit.html")
def entry_exit_page():
    return send_from_directory(str(FRONTEND_DIR), "entry-exit.html")

@app.get("/history")
@app.get("/history.html")
def parking_history_page():
    return send_from_directory(str(FRONTEND_DIR), "history.html")

@app.get("/events")
@app.get("/events.html")
def events_page():
    return send_from_directory(str(FRONTEND_DIR), "events.html")

@app.get("/parking-slots")
@app.get("/parking-slots.html")
def parking_slots_page():
    return send_from_directory(str(FRONTEND_DIR), "parking-slots.html")

@app.get("/sidebar.js")
def sidebar_js():
    return send_from_directory(str(FRONTEND_DIR), "sidebar.js")

@app.get("/style.css")
def stylesheet():
    return send_from_directory(str(FRONTEND_DIR), "style.css")

@app.get("/app.js")
def frontend_app_js():
    return send_from_directory(str(FRONTEND_DIR), "app.js")


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
        # Automatic daily status synchronization based on current date
        today = datetime.date.today().isoformat()
        try:
            # Mark past events completed
            db.table("wedding_events").update({"status": "completed"}).lt("event_date", today).neq("status", "completed").execute()
            # Auto-activate today's planned events
            db.table("wedding_events").update({"status": "active"}).eq("event_date", today).eq("status", "planned").execute()
        except Exception as sync_exc:
            print("Daily event status sync notice:", sync_exc)

        events = run_query(
            db.table("wedding_events")
            .select("event_id, event_name, event_date, status")
            .order("event_date", desc=True)
        )

        return jsonify({"events": events, "today": today})

    except Exception as exc:
        print("EVENTS ERROR:", repr(exc))
        return response_error("Could not load events: " + str(exc), 500)


@app.post("/api/events")
def create_event():
    """Create a new wedding event."""
    _, _, error = require_staff()

    if error:
        return error

    body = request.get_json(silent=True) or {}
    name = str(body.get("event_name", "")).strip()
    event_date = str(body.get("event_date", "")).strip()
    status = str(body.get("status", "auto")).strip().lower()

    if not name:
        return response_error("Event name is required.")
    if not event_date:
        return response_error("Event date is required.")

    today = datetime.date.today().isoformat()
    if status == "auto" or status not in {"planned", "active", "completed"}:
        if event_date < today:
            status = "completed"
        elif event_date == today:
            status = "active"
        else:
            status = "planned"

    try:
        new_event = run_query(
            db.table("wedding_events")
            .insert({
                "event_name": name,
                "event_date": event_date,
                "status": status
            })
            .select()
            .single()
        )
        return jsonify({
            "message": "Event created successfully.",
            "event": new_event
        }), 201

    except Exception as exc:
        return response_error("Failed to create event: " + str(exc), 500)


@app.put("/api/events/<int:event_id>")
def update_event(event_id):
    """Update event date and/or status."""
    _, _, error = require_staff()

    if error:
        return error

    body = request.get_json(silent=True) or {}
    update_data = {}

    if "event_name" in body:
        update_data["event_name"] = str(body["event_name"]).strip()
    if "event_date" in body:
        update_data["event_date"] = str(body["event_date"]).strip()
    if "status" in body:
        st = str(body["status"]).strip().lower()
        if st in {"planned", "active", "completed"}:
            update_data["status"] = st

    if not update_data:
        return response_error("No fields provided to update.")

    try:
        updated = run_query(
            db.table("wedding_events")
            .update(update_data)
            .eq("event_id", event_id)
            .select()
            .single()
        )
        return jsonify({
            "message": "Event updated successfully.",
            "event": updated
        })

    except Exception as exc:
        return response_error("Failed to update event: " + str(exc), 500)


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
                (session.get("vehicles") or {}).get(
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
    _, _, error = require_staff()

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
        # Check that the event exists and is ACTIVE.
        event = run_query(
            db.table("wedding_events")
            .select("event_id, status")
            .eq("event_id", event_id)
            .maybe_single()
        )

        if not event:
            return response_error("Wedding event not found.", 404)

        if event["status"] != "active":
            return response_error(
                "Vehicle entry is allowed only for active events. Current event status is " + str(event["status"])
            )

        # Reuse an existing vehicle when its number is known.
        existing = run_query(
            db.table("vehicles")
            .select("vehicle_id")
            .eq("registration_number", registration)
            .maybe_single()
        )

        if existing:
            vehicle_id = existing["vehicle_id"]
        else:
            new_vehicle = run_query(
                db.table("vehicles")
                .insert({
                    "registration_number": registration,
                    "vehicle_type": vehicle_type,
                    "guest_name": guest_name or None,
                    "guest_contact": guest_contact or None
                })
                .select("vehicle_id")
                .single()
            )

            vehicle_id = new_vehicle["vehicle_id"]

        # Use the existing database function for slot assignment.
        result = run_query(
            db.rpc(
                "register_vehicle_entry",
                {
                    "p_event_id": event_id,
                    "p_vehicle_id": vehicle_id
                }
            )
        )

        assigned = result[0] if isinstance(result, list) else result

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
    _, _, error = require_staff()

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
        result = run_query(
            db.rpc(
                "register_vehicle_exit",
                {
                    "p_registration_number": registration
                }
            )
        )

        exited = result[0] if isinstance(result, list) else result

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

        return jsonify({"sessions": sessions})

    except ValueError:
        return response_error("Select a valid wedding event.")

    except Exception as exc:
        return response_error(str(exc), 500)


# -------------------- START SERVER --------------------

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)
