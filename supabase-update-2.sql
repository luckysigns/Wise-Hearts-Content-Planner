-- ============================================================
-- WISE HEART PLANNER — update #2: views + podcasts
-- Paste into: Supabase Dashboard > SQL Editor > Run
-- Adds view-count columns and the podcast table.
-- Does NOT touch your existing follower numbers. Safe to run twice.
-- ============================================================

-- 1. Lifetime view counts, logged each Thursday alongside followers
alter table public.weekly_stats add column if not exists youtube_views   bigint;
alter table public.weekly_stats add column if not exists tiktok_views    bigint;
alter table public.weekly_stats add column if not exists instagram_views bigint;

-- 2. Podcast guests + pipeline
create table if not exists public.podcasts (
  id          uuid primary key default gen_random_uuid(),
  guest       text not null,
  stage       text not null default 'idea',      -- idea | reached_out | confirmed | recorded
  format      text,                              -- virtual | in_person
  record_date date,
  record_time time,
  topic       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists podcasts_date_idx  on public.podcasts (record_date);
create index if not exists podcasts_stage_idx on public.podcasts (stage);

-- No-login access, same as the weekly numbers
alter table public.podcasts enable row level security;
drop policy if exists "pod open read"   on public.podcasts;
drop policy if exists "pod open insert" on public.podcasts;
drop policy if exists "pod open update" on public.podcasts;
drop policy if exists "pod open delete" on public.podcasts;
create policy "pod open read"   on public.podcasts for select using (true);
create policy "pod open insert" on public.podcasts for insert with check (true);
create policy "pod open update" on public.podcasts for update using (true);
create policy "pod open delete" on public.podcasts for delete using (true);
