import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function Dashboard() {
  const [userId, setUserId] = useState<string | null>(null)
  const [email, setEmail] = useState<string | null>(null)
  const [role, setRole] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const { data } = await supabase.auth.getSession()
      if (cancelled) return
      setUserId(data.session?.user?.id ?? null)
      setEmail(data.session?.user?.email ?? null)

      try {
        const { data: profileData } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', data.session?.user?.id)
          .single()
        if (!cancelled) setRole(profileData?.role ?? null)
      } catch (e) {
        // profiles schema not created yet; keep dashboard usable.
        console.warn('Could not load profile role yet:', e)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  return (
    <section style={{ maxWidth: 900 }}>
      <h1 style={{ marginTop: 0 }}>Subscriber dashboard</h1>
      <p style={{ color: '#6b7280' }}>
        Authenticated via Supabase JWT. (Phase 1 placeholder until DB schema is ready.)
      </p>

      <div
        style={{
          border: '1px solid #e5e7eb',
          borderRadius: 12,
          padding: 16,
          background: '#fafafa',
          marginTop: 16,
        }}
      >
        <div>
          <strong>User ID:</strong> {userId ?? '—'}
        </div>
        <div>
          <strong>Email:</strong> {email ?? '—'}
        </div>
        <div>
          <strong>Role:</strong> {role ?? '—'}
        </div>
      </div>

      <div style={{ marginTop: 20, color: '#6b7280' }}>
        Next: subscription status, last 5 scores (rolling), charity selection, participation + winnings.
      </div>
    </section>
  )
}

