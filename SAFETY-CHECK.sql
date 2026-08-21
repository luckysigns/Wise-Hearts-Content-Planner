-- ============================================================
-- SHARED-PROJECT SAFETY CHECK
-- Run this in Supabase SQL Editor BEFORE supabase-update-3.sql.
-- Read-only — it changes nothing, just tells you what's already there.
-- ============================================================

-- 1. Name collisions. Any row returned here means something already
--    owns that name and update-3 would be touching it.
--    Expect: weekly_stats + podcasts (yours, from this app). Nothing else.
select tablename as existing_table
from pg_tables
where schemaname = 'public'
  and tablename in ('weekly_stats', 'podcasts', 'wise_heart_config', 'app_config');

-- 2. Cron job name collision. Expect: no rows.
--    (If pg_cron isn't installed yet this errors — that's fine, means no jobs.)
select jobname, schedule from cron.job where jobname = 'wise-heart-weekly-sync';

-- 3. THE IMPORTANT ONE — tables in this project with RLS switched OFF.
--    The planner app is published publicly on Vercel with this project's
--    publishable key inside it. Any table listed here is readable by anyone
--    who opens the app and looks. Streakly tables should NOT appear.
select tablename as table_without_rls
from pg_tables
where schemaname = 'public' and rowsecurity = false
order by tablename;

-- 4. Tables that have RLS on but no policies are locked down (good),
--    while tables with permissive policies are open. Review anything
--    that isn't weekly_stats or podcasts.
select t.tablename,
       t.rowsecurity as rls_on,
       count(p.policyname) as policy_count
from pg_tables t
left join pg_policies p
  on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public'
group by t.tablename, t.rowsecurity
order by t.rowsecurity, t.tablename;
