import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://szjprsarixeeqkcqfush.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_YRNNGcAdvStAWsv7RvnaeQ_JUjpNqXM';

export const supabase = createClient(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
);

export async function getStaffProfile(userId) {
    const { data, error } = await supabase
        .from('profiles')
        .select('id, auth_uid, full_name, role')
        .or(`id.eq.${userId},auth_uid.eq.${userId}`)
        .maybeSingle();
    return { profile: data, error };
}

export async function requireRole(allowedRoles) {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
        window.location.replace('/');
        return null;
    }

    const { profile, error } = await getStaffProfile(session.user.id);

    if (error || !profile) {
        console.error('Could not load staff profile:', error);
        await supabase.auth.signOut();
        window.location.replace('/');
        return null;
    }

    // DEBUG: Check what role is detected in the browser console
    console.log('Logged-in user profile:', profile);
    console.log('Allowed roles for this page:', allowedRoles);

    if (!allowedRoles.includes(profile.role)) {
        console.warn(`Role "${profile.role}" is not authorized for this page. Redirecting...`);
        window.location.replace('/dashboard.html');
        return null;
    }

    return { session, profile };
}

export async function apiRequest(path, options = {}) {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
        window.location.replace('/');
        throw new Error('Please sign in again.');
    }

    const response = await fetch(path, {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            ...options.headers,
            Authorization: `Bearer ${session.access_token}`
        }
    });

    const payload = await response.text();
    let result = {};
    if (payload) {
        try {
            result = JSON.parse(payload);
        } catch {
            throw new Error(
                response.ok
                    ? 'The server returned an unexpected response.'
                    : `Request failed (${response.status}).`
            );
        }
    }

    if (!response.ok) {
        throw new Error(result.error || 'The request could not be completed.');
    }

    return result;
}

console.log('Supabase client initialized!');