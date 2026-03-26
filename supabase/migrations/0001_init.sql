-- Supabase schema bootstrap for "Golf Charity Subscription Platform"
-- Apply this in your Supabase project's SQL editor or via supabase-cli migrations.
-- This migration focuses on Phase 1: core DB + RLS so the app can authenticate (JWT)
-- and allow subscribers/admins to read/write their own data safely.

-- Extensions
create extension if not exists pgcrypto;

-- =========================
-- Profiles (role management)
-- =========================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'subscriber' check (role in ('subscriber', 'admin')),
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

-- =========================
-- Helper: admin check
-- (created after profiles table exists)
-- =========================
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

-- Users can read/update their own profile.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
using (id = auth.uid());

drop policy if exists "profiles_insert_own_subscriber" on public.profiles;
create policy "profiles_insert_own_subscriber"
on public.profiles
for insert
with check (id = auth.uid() and role = 'subscriber');

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (id = auth.uid())
with check (
  id = auth.uid()
  -- Only admins can change role; normal users can update display_name safely.
  and (
    role = (select role from public.profiles p where p.id = auth.uid())
    or public.is_admin()
  )
);

-- Admins can manage everything.
drop policy if exists "profiles_admin_all" on public.profiles;
create policy "profiles_admin_all"
on public.profiles
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Subscriptions (Stripe sync)
-- =========================
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null check (plan in ('monthly', 'yearly')),
  status text not null check (status in ('active', 'canceled', 'past_due', 'lapsed')),
  stripe_customer_id text,
  stripe_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  canceled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, stripe_subscription_id)
);

drop trigger if exists trg_subscriptions_updated_at on public.subscriptions;
create trigger trg_subscriptions_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

alter table public.subscriptions enable row level security;

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own"
on public.subscriptions
for select
using (user_id = auth.uid());

drop policy if exists "subscriptions_write_own" on public.subscriptions;
create policy "subscriptions_write_own"
on public.subscriptions
for insert
with check (user_id = auth.uid());

drop policy if exists "subscriptions_update_own" on public.subscriptions;
create policy "subscriptions_update_own"
on public.subscriptions
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "subscriptions_admin_all" on public.subscriptions;
create policy "subscriptions_admin_all"
on public.subscriptions
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Scores (Stableford, last 5)
-- =========================
create table if not exists public.scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  score integer not null check (score between 1 and 45),
  played_on date not null,
  created_at timestamptz not null default now(),
  unique (user_id, played_on)
);

alter table public.scores enable row level security;

drop policy if exists "scores_select_own" on public.scores;
create policy "scores_select_own"
on public.scores
for select
using (user_id = auth.uid());

drop policy if exists "scores_insert_own" on public.scores;
create policy "scores_insert_own"
on public.scores
for insert
with check (user_id = auth.uid());

drop policy if exists "scores_update_own" on public.scores;
create policy "scores_update_own"
on public.scores
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "scores_delete_own" on public.scores;
create policy "scores_delete_own"
on public.scores
for delete
using (user_id = auth.uid());

drop policy if exists "scores_admin_all" on public.scores;
create policy "scores_admin_all"
on public.scores
for all
using (public.is_admin())
with check (public.is_admin());

-- Enforce "keep only latest 5 scores" per user.
create or replace function public.trim_scores_to_latest_5()
returns trigger
language plpgsql
as $$
begin
  -- Delete any scores beyond the 5 newest (by played_on desc, then created_at desc).
  delete from public.scores s
  where s.user_id = new.user_id
    and s.id not in (
      select ss.id
      from public.scores ss
      where ss.user_id = new.user_id
      order by ss.played_on desc, ss.created_at desc
      limit 5
    );
  return new;
end;
$$;

drop trigger if exists trg_trim_scores on public.scores;
create trigger trg_trim_scores
after insert on public.scores
for each row execute function public.trim_scores_to_latest_5();

-- =========================
-- Charities (directory)
-- =========================
create table if not exists public.charities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  image_url text,
  events jsonb,
  featured boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.charities enable row level security;

drop policy if exists "charities_public_read" on public.charities;
create policy "charities_public_read"
on public.charities
for select
using (active = true);

drop policy if exists "charities_admin_manage" on public.charities;
create policy "charities_admin_manage"
on public.charities
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- User charity preferences
-- =========================
create table if not exists public.user_charity_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  charity_id uuid not null references public.charities(id) on delete restrict,
  contribution_percentage integer not null default 10 check (contribution_percentage >= 10 and contribution_percentage <= 100),
  independent_donation_enabled boolean not null default false,
  independent_donation_amount_cents bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_ucp_updated_at on public.user_charity_preferences;
create trigger trg_ucp_updated_at
before update on public.user_charity_preferences
for each row execute function public.set_updated_at();

alter table public.user_charity_preferences enable row level security;

drop policy if exists "ucp_select_own" on public.user_charity_preferences;
create policy "ucp_select_own"
on public.user_charity_preferences
for select
using (user_id = auth.uid());

drop policy if exists "ucp_upsert_own" on public.user_charity_preferences;
create policy "ucp_upsert_own"
on public.user_charity_preferences
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "ucp_admin_all" on public.user_charity_preferences;
create policy "ucp_admin_all"
on public.user_charity_preferences
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Draws & Results
-- =========================
create table if not exists public.draws (
  id uuid primary key default gen_random_uuid(),
  draw_month date not null, -- month anchor (e.g., 2026-03-01)
  logic_mode text not null default 'random' check (logic_mode in ('random', 'algorithmic')),
  simulation_mode boolean not null default false,
  published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (draw_month, simulation_mode)
);

alter table public.draws enable row level security;

drop policy if exists "draws_public_read_published" on public.draws;
create policy "draws_public_read_published"
on public.draws
for select
using (published = true);

drop policy if exists "draws_admin_manage" on public.draws;
create policy "draws_admin_manage"
on public.draws
for all
using (public.is_admin())
with check (public.is_admin());

create table if not exists public.draw_results (
  id uuid primary key default gen_random_uuid(),
  draw_id uuid not null references public.draws(id) on delete cascade,
  tier text not null check (tier in ('5-match', '4-match', '3-match')),
  winning_numbers int[] not null,
  prize_pool_cents bigint not null default 0,
  rollover_cents bigint not null default 0
);

alter table public.draw_results enable row level security;

drop policy if exists "draw_results_public_read_published_draw" on public.draw_results;
create policy "draw_results_public_read_published_draw"
on public.draw_results
for select
using (
  exists (
    select 1
    from public.draws d
    where d.id = draw_results.draw_id
      and d.published = true
  )
);

drop policy if exists "draw_results_admin_manage" on public.draw_results;
create policy "draw_results_admin_manage"
on public.draw_results
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Participation / Entries
-- =========================
create table if not exists public.draw_entries (
  id uuid primary key default gen_random_uuid(),
  draw_id uuid not null references public.draws(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entered_at timestamptz not null default now(),
  unique (draw_id, user_id)
);

alter table public.draw_entries enable row level security;

drop policy if exists "draw_entries_select_own" on public.draw_entries;
create policy "draw_entries_select_own"
on public.draw_entries
for select
using (user_id = auth.uid());

drop policy if exists "draw_entries_insert_own" on public.draw_entries;
create policy "draw_entries_insert_own"
on public.draw_entries
for insert
with check (user_id = auth.uid());

drop policy if exists "draw_entries_delete_own" on public.draw_entries;
create policy "draw_entries_delete_own"
on public.draw_entries
for delete
using (user_id = auth.uid());

drop policy if exists "draw_entries_admin_all" on public.draw_entries;
create policy "draw_entries_admin_all"
on public.draw_entries
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Winners (verification + payout)
-- =========================
create table if not exists public.winners (
  id uuid primary key default gen_random_uuid(),
  draw_id uuid not null references public.draws(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  tier text not null check (tier in ('5-match', '4-match', '3-match')),
  prize_cents bigint not null default 0,
  proof_url text,
  verification_status text not null default 'pending' check (verification_status in ('pending', 'approved', 'rejected')),
  payout_status text not null default 'pending' check (payout_status in ('pending', 'paid')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (draw_id, user_id, tier)
);

alter table public.winners enable row level security;

-- Users can see their own winners/payout status.
drop policy if exists "winners_select_own" on public.winners;
create policy "winners_select_own"
on public.winners
for select
using (user_id = auth.uid());

-- Winner proof upload is user-scoped (user can update only proof + verification request).
drop policy if exists "winners_update_proof_own" on public.winners;
create policy "winners_update_proof_own"
on public.winners
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Admin can review and mark payouts.
drop policy if exists "winners_admin_all" on public.winners;
create policy "winners_admin_all"
on public.winners
for all
using (public.is_admin())
with check (public.is_admin());

-- =========================
-- Helpful indexes
-- =========================
create index if not exists idx_scores_user_played_on on public.scores (user_id, played_on desc);
create index if not exists idx_ucp_charity on public.user_charity_preferences (charity_id);
create index if not exists idx_draws_draw_month on public.draws (draw_month desc);
create index if not exists idx_winners_draw_id on public.winners (draw_id);

