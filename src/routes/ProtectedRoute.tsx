import { PropsWithChildren, useEffect, useMemo, useState } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'

type Props = PropsWithChildren<{
  requireAdmin?: boolean
}>

async function getUserRole(userId: string): Promise<'admin' | 'subscriber'> {
  // Expects a `profiles` table with a `role` column.
  // During early development, you can temporarily create the table + RLS policies.
  const { data, error } = await supabase.from('profiles').select('role').eq('id', userId).single()
  if (error) throw error

  return (data?.role as 'admin' | 'subscriber') ?? 'subscriber'
}

export default function ProtectedRoute({ children, requireAdmin }: Props) {
  const location = useLocation()
  const [loading, setLoading] = useState(true)
  const [isAllowed, setIsAllowed] = useState(false)

  useEffect(() => {
    let cancelled = false

    ;(async () => {
      setLoading(true)
      try {
        const { data } = await supabase.auth.getSession()
        const session = data.session
        if (!session?.user) {
          if (!cancelled) setIsAllowed(false)
          return
        }

        if (!requireAdmin) {
          if (!cancelled) setIsAllowed(true)
          return
        }

        const role = await getUserRole(session.user.id)
        if (!cancelled) setIsAllowed(role === 'admin')
      } catch {
        if (!cancelled) setIsAllowed(false)
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()

    return () => {
      cancelled = true
    }
  }, [requireAdmin])

  const redirectToLogin = useMemo(() => {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }, [location.pathname])

  if (loading) return <div style={{ padding: 20 }}>Loading...</div>
  if (!isAllowed) return redirectToLogin

  return children
}

