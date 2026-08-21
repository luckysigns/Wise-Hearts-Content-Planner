-- ============================================================
-- RECONCILE — run this FIRST, before anything else.
-- Read-only. Tells us what the earlier update-3 actually did.
-- Paste the output back to Claude.
-- ============================================================

-- A. Does app_config exist, and is it mine or Streakly's?
--    Mine has exactly 3 columns: key, value, updated_at.
--    Anything else = it was already yours and I touched it.
select
  c.relname                                   as table_name,
  (select count(*) from pg_attribute a
     where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped) as column_count,
  c.relrowsecurity                            as rls_now_on,
  (select count(*) from pg_policies p
     where p.schemaname = 'public' and p.tablename = 'app_config') as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'app_config';
-- No rows returned = app_config doesn't exist at all (nothing to worry about).

-- B. What columns does it have? (Confirms whose table it is.)
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'app_config'
order by ordinal_position;

-- C. Does it contain data? Mine would be empty (Instagram was never set up).
select count(*) as row_count from public.app_config;

-- D. Did a cron job get created, and does it point somewhere real?
select jobname, schedule, active,
       case when command like '%PROJECT_REF%' or command like '%SERVICE_KEY%'
            then 'BROKEN — placeholders were never replaced'
            else 'looks filled in' end as status
from cron.job;

-- E. Confirm the weekly_stats columns landed (these are safe, additive).
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'weekly_stats'
  and column_name in ('auto_at','needs_review','youtube_views','tiktok_views','instagram_views');

-- F. The big one — anything in this project readable by the public app key.
select tablename as table_without_rls
from pg_tables where schemaname = 'public' and rowsecurity = false
order by tablename;
