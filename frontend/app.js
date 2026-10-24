import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL ='https://szjprsarixeeqkcqfush.supabase.co';
const SUPABASE_PUBLISHABLE_KEY ='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6anByc2FyaXhlZXFrY3FmdXNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1MTE0OTAsImV4cCI6MjEwODA4NzQ5MH0.9r4w68olenhGCdfMdQ86CFxvYnoYzMQye-aij1Q2Pco';

export const supabase = createClient(
    SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY
);

console.log('Supabase client initialized!');
