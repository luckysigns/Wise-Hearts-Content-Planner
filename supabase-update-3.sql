-- ============================================================
-- WISE HEART PLANNER — update #3: automatic weekly sync
-- Paste into: Supabase Dashboard > SQL Editor > Run
-- Run this BEFORE deploying the weekly-sync Edge Function.
-- Safe to run twice. Does not touch existing data.
-- ============================================================

-- 1. Track which rows the robot filled and which still need your eyes
alter table public.weekly_stats add column if not exists auto_at      timestamptz;
alter table public.weekly_stats add column if not exists needs_review boolean not null default false;

-- 2. Somewhere to keep the Instagram token, which rotates every 60 days.
--    NOTE: no public policies here on purpose — only the Edge Function
--    (which uses the service role key) can read or write this table.
create table if not exists public.wise_heart_config (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now()
);
alter table public.wise_heart_config enable row level security;
-- deliberately no policies: anon/public access is denied by default

-- 3. Extensions needed to call the Edge Function on a schedule
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ============================================================
-- 4. THE WEEKLY SCHEDULE
--    Fill in the two placeholders below, then run this part.
--    - PROJECT_REF : from your Supabase URL (https://PROJECT_REF.supabase.co)
--    - SERVICE_KEY : Project Settings > API > service_role key (SECRET —
--                    it lives only here in your database, never in the app)
--    Runs every Thursday at 8:00am UTC (~1am Portland). Adjust if you like.
-- ============================================================

-- Remove any previous copy of the job so this stays re-runnable
select cron.unschedule('wise-heart-weekly-sync')
where exists (select 1 from cron.job where jobname = 'wise-heart-weekly-sync');

select cron.schedule(
  'wise-heart-weekly-sync',
  '0 8 * * 4',
  $$
  select net.http_post(
    url     := 'https://PROJECT_REF.supabase.co/functions/v1/weekly-sync',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer SERVICE_KEY'
               ),
    body    := '{}'::jsonb
  );
  $$
);

-- ============================================================
-- Handy checks (run these any time)
-- ============================================================
-- What's scheduled?
--   select jobname, schedule, active from cron.job;
--
-- Did the last few runs work?
--   select start_time, status, return_message
--   from cron.job_run_details order by start_time desc limit 10;
--
-- Which weeks are waiting on your manual numbers?
--   select week_date, youtube, tiktok, instagram, needs_review
--   from weekly_stats where needs_review order by week_date desc;
