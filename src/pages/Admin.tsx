import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabaseClient'

export default function Admin() {
  const [userId, setUserId] = useState<string | null>(null)
  const [role, setRole] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const { data } = await supabase.auth.getSession()
      if (cancelled) return
      setUserId(data.session?.user?.id ?? null)

      try {
        const { data: profileData } = await supabase
          .from('profiles')
          .select('role')
          .eq('id', data.session?.user?.id)
          .single()
        if (!cancelled) setRole(profileData?.role ?? null)
      } catch (e) {
        console.warn('Could not load admin role yet:', e)
      }
    })()

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <section style={{ maxWidth: 900 }}>
      <h1 style={{ marginTop: 0 }}>Admin dashboard</h1>
      <p style={{ color: '#6b7280' }}>Protected (admin role required). Next: draw config, winner verification, charities.</p>

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
          <strong>Role:</strong> {role ?? '—'}
        </div>
      </div>
    </section>
  )
}

