# Golf Charity Subscription Platform (React + Supabase)

## Local setup

1. Create a Supabase project.
2. Copy `.env.example` to `.env` and fill in:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
3. Install dependencies and start:

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Notes

- Phase 1 includes Supabase Auth + a `profiles.role`-based admin guard scaffold.
- Create the `profiles` table in Supabase before fully testing `/dashboard` and `/admin`.

