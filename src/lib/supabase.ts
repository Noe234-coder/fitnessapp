import { createClient } from '@supabase/supabase-js'

import type { Database } from './database.types'
import { getEnv } from './env'

const env = getEnv()

// The publishable key only: every table is protected by RLS. Anything that
// needs more than that runs in an Edge Function, never in the client.
export const supabase = createClient<Database>(
  env.VITE_SUPABASE_URL,
  env.VITE_SUPABASE_PUBLISHABLE_KEY,
)
