import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

const isConfigured = Boolean(supabaseUrl && supabaseAnonKey)

// Avoid crashing the whole UI before env vars are configured.
// Auth calls will fail until you set a real `.env`.
export const supabase = createClient(
  isConfigured ? (supabaseUrl as string) : 'https://example.supabase.co',
  isConfigured ? (supabaseAnonKey as string) : 'public-anon-key',
  {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
  },
)

if (!isConfigured) {
  console.warn('Supabase env vars missing: set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in `.env`.')
}

