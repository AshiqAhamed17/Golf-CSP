# Supabase Setup (Phase 1)

## 1. Apply the SQL migration

You can apply it in either way:

### Option A: Supabase SQL editor (quick)
1. Open your Supabase project in the dashboard.
2. Go to `SQL Editor`.
3. Paste the contents of:
   - `supabase/migrations/0001_init.sql`
4. Run.

### Option B: Supabase CLI (recommended if you plan multiple migrations)
1. Install/configure Supabase CLI.
2. Add a `supabase/config.toml` (optional).
3. Run migrations using your CLI workflow.

## 2. Create an admin user role (only for initial bootstrap)

After you sign up your first user in the app, you must mark them as `admin` manually.

Run in SQL editor:

```sql
update public.profiles
set role = 'admin'
where id = '<PUT_AUTH_USER_UUID_HERE>';
```

## 3. Verify RLS works with the app

- `/dashboard` works for any authenticated user (role not required).
- `/admin` requires that `public.profiles.role = 'admin'` for the logged-in user.

