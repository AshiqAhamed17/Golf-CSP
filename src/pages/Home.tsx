import { Link } from 'react-router-dom'

export default function Home() {
  return (
    <section style={{ maxWidth: 920 }}>
      <h1 style={{ marginTop: 0 }}>Golf Charity Subscription</h1>
      <p style={{ color: '#6b7280', lineHeight: 1.5 }}>
        Track your last 5 Stableford scores, enter monthly prize draws, and support a charity of your choice.
      </p>
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginTop: 18 }}>
        <Link to="/login" style={{ padding: '10px 14px', border: '1px solid #e5e7eb', borderRadius: 10 }}>
          Login / Sign up
        </Link>
        <Link
          to="/dashboard"
          style={{ padding: '10px 14px', background: '#111827', color: 'white', borderRadius: 10 }}
        >
          Go to dashboard
        </Link>
      </div>
    </section>
  )
}

