-- Create a table for application user profiles--
--TABLES--
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'attendant'
        CHECK (role IN ('admin', 'manager', 'attendant')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Enable Row-Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.wedding_events (
    event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_name TEXT NOT NULL,
    event_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'active', 'completed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.wedding_events ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.vehicles (
    vehicle_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    registration_number TEXT NOT NULL UNIQUE,
    vehicle_type TEXT NOT NULL
        CHECK (vehicle_type IN ('car', 'suv', 'bike', 'van', 'other')),
    guest_name TEXT,
    guest_contact TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.parking_slots (
    slot_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slot_number INTEGER NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'unavailable')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.parking_slots ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.parking_sessions (
    session_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    event_id BIGINT NOT NULL
        REFERENCES public.wedding_events(event_id),

    vehicle_id BIGINT NOT NULL
        REFERENCES public.vehicles(vehicle_id),

    slot_id BIGINT NOT NULL
        REFERENCES public.parking_slots(slot_id),

    entry_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    exit_time TIMESTAMPTZ,

    entry_recorded_by UUID
        REFERENCES public.profiles(id),

    exit_recorded_by UUID
        REFERENCES public.profiles(id),

    CHECK (exit_time IS NULL OR exit_time >= entry_time)
);
ALTER TABLE public.parking_sessions
ENABLE ROW LEVEL SECURITY;


CREATE TABLE public.parking_events (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    session_id BIGINT NOT NULL
        REFERENCES public.parking_sessions(session_id),

    action_type TEXT NOT NULL
        CHECK (action_type IN ('entry', 'exit')),

    action_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    performed_by UUID
        REFERENCES public.profiles(id),

    notes TEXT
);
ALTER TABLE public.parking_events
ENABLE ROW LEVEL SECURITY;