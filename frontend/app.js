
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://szjprsarixeeqkcqfush.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_YRNNGcAdvStAWsv7RvnaeQ_JUjpNqXM';

export const supabase = createClient(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
);

console.log('Supabase client initialized!');
