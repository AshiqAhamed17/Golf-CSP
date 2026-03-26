import { FormEvent, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'

export default function Login() {
  const navigate = useNavigate()

  const [mode, setMode] = useState<'login' | 'signup'>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      if (mode === 'login') {
        const { error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
        navigate('/dashboard')
        return
      }

      // signup
      const { data, error } = await supabase.auth.signUp({ email, password })
      if (error) throw error

      // If email confirmations are disabled in Supabase, `data.user` is available immediately.
      // Otherwise the profile insert will fail until the user exists.
      if (data.user) {
        const { error: profileError } = await supabase.from('profiles').insert({
          id: data.user.id,
          role: 'subscriber',
        })

        if (profileError) {
          // Table might not exist yet during early scaffolding; don't block signup UI.
          console.warn('Profile insert failed (schema not ready yet):', profileError)
        }
        navigate('/dashboard')
      }
    } catch (err: any) {
      setError(err?.message ?? 'Authentication failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <section style={{ maxWidth: 520 }}>
      <h1 style={{ marginTop: 0 }}>{mode === 'login' ? 'Login' : 'Create account'}</h1>
      <p style={{ color: '#6b7280', marginTop: 0 }}>
        Use your Supabase Auth to get a JWT for authenticated access.
      </p>

      <form onSubmit={onSubmit} style={{ display: 'grid', gap: 10 }}>
        <label>
          <span style={{ display: 'block', marginBottom: 6 }}>Email</span>
          <input
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            type="email"
            required
            style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #e5e7eb' }}
          />
        </label>

        <label>
          <span style={{ display: 'block', marginBottom: 6 }}>Password</span>
          <input
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            type="password"
            required
            minLength={6}
            style={{ width: '100%', padding: 10, borderRadius: 8, border: '1px solid #e5e7eb' }}
          />
        </label>

        {error ? (
          <div style={{ color: '#b91c1c', background: '#fef2f2', padding: 10, borderRadius: 8 }}>{error}</div>
        ) : null}

        <button
          type="submit"
          disabled={loading}
          style={{
            padding: 12,
            borderRadius: 10,
            border: 'none',
            cursor: loading ? 'not-allowed' : 'pointer',
            background: '#111827',
            color: 'white',
          }}
        >
          {loading ? 'Please wait...' : mode === 'login' ? 'Login' : 'Sign up'}
        </button>
      </form>

      <div style={{ marginTop: 14, color: '#6b7280' }}>
        {mode === 'login' ? (
          <>
            Don&apos;t have an account?{' '}
            <button
              onClick={() => setMode('signup')}
              style={{ border: 'none', background: 'transparent', color: '#2563eb', cursor: 'pointer' }}
              type="button"
            >
              Create one
            </button>
          </>
        ) : (
          <>
            Already registered?{' '}
            <button
              onClick={() => setMode('login')}
              style={{ border: 'none', background: 'transparent', color: '#2563eb', cursor: 'pointer' }}
              type="button"
            >
              Login
            </button>
          </>
        )}
      </div>

      <div style={{ marginTop: 12 }}>
        <Link to="/">Back to home</Link>
      </div>
    </section>
  )
}

