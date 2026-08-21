-- ============================================================
-- WISE HEART CONTENT PLANNER - Supabase setup
-- Paste this whole file into: Supabase Dashboard > SQL Editor > Run
-- It creates the table, opens access (no logins), and imports
-- all 72 weeks from your spreadsheet. Safe to run twice.
-- ============================================================

create table if not exists public.weekly_stats (
  week_date  date primary key,
  youtube    integer not null default 0,
  tiktok     integer not null default 0,
  instagram  integer not null default 0,
  notes      text,
  updated_at timestamptz not null default now()
);

-- No-login access: anyone with your app's link can read and write.
alter table public.weekly_stats enable row level security;
drop policy if exists "open read"   on public.weekly_stats;
drop policy if exists "open insert" on public.weekly_stats;
drop policy if exists "open update" on public.weekly_stats;
drop policy if exists "open delete" on public.weekly_stats;
create policy "open read"   on public.weekly_stats for select using (true);
create policy "open insert" on public.weekly_stats for insert with check (true);
create policy "open update" on public.weekly_stats for update using (true);
create policy "open delete" on public.weekly_stats for delete using (true);

-- Your spreadsheet history (Feb 27, 2025 - Jul 9, 2026)
insert into public.weekly_stats (week_date, youtube, tiktok, instagram, notes) values
('2025-02-27', 25, 14, 4, null),
('2025-03-06', 34, 49, 7, null),
('2025-03-13', 39, 71, 9, null),
('2025-03-20', 44, 75, 11, null),
('2025-03-27', 47, 85, 11, null),
('2025-04-03', 48, 91, 12, null),
('2025-04-10', 51, 102, 12, null),
('2025-04-17', 54, 114, 12, null),
('2025-04-24', 56, 196, 14, null),
('2025-05-01', 61, 226, 15, null),
('2025-05-08', 65, 269, 18, null),
('2025-05-15', 67, 320, 18, null),
('2025-05-22', 78, 376, 18, null),
('2025-05-29', 82, 414, 19, 'YT 6, TT 29, IN 1.2'),
('2025-06-05', 91, 436, 19, null),
('2025-06-12', 93, 459, 19, null),
('2025-06-19', 99, 470, 19, null),
('2025-06-26', 102, 492, 19, null),
('2025-07-03', 114, 505, 19, null),
('2025-07-10', 121, 516, 19, null),
('2025-07-17', 133, 528, 23, null),
('2025-07-24', 148, 540, 23, null),
('2025-07-31', 167, 549, 23, null),
('2025-08-07', 175, 570, 24, null),
('2025-08-14', 191, 597, 25, null),
('2025-08-21', 210, 616, 25, null),
('2025-08-28', 218, 620, 25, 'YT 8, TT 23, IN  0.9'),
('2025-09-04', 230, 630, 26, null),
('2025-09-11', 234, 637, 26, null),
('2025-09-18', 242, 642, 26, null),
('2025-09-25', 342, 650, 26, null),
('2025-10-02', 556, 676, 26, null),
('2025-10-09', 742, 703, 26, null),
('2025-10-16', 850, 706, 26, null),
('2025-10-23', 873, 706, 26, null),
('2025-10-30', 894, 719, 27, null),
('2025-11-06', 912, 785, 28, null),
('2025-11-13', 922, 794, 29, null),
('2025-11-20', 940, 797, 30, null),
('2025-11-27', 951, 823, 31, 'YT 24 TT 20 IN 0.7'),
('2025-12-04', 958, 830, 31, null),
('2025-12-11', 971, 834, 31, null),
('2025-12-18', 981, 837, 31, null),
('2025-12-25', 989, 842, 31, null),
('2026-01-01', 993, 846, 31, null),
('2026-01-08', 1004, 851, 31, null),
('2026-01-15', 1018, 854, 31, null),
('2026-01-22', 1031, 871, 31, null),
('2026-01-29', 1041, 883, 31, null),
('2026-02-05', 1059, 900, 30, null),
('2026-02-12', 1099, 902, 30, null),
('2026-02-19', 1116, 900, 30, null),
('2026-02-26', 1135, 897, 30, 'YT 21, TT 17, IN 0.5'),
('2026-03-05', 1145, 891, 31, null),
('2026-03-12', 1162, 892, 31, null),
('2026-03-19', 1171, 898, 31, null),
('2026-03-26', 1192, 903, 33, null),
('2026-04-02', 1209, 903, 32, null),
('2026-04-09', 1238, 912, 32, null),
('2026-04-16', 1240, 917, 32, null),
('2026-04-23', 1259, 919, 33, null),
('2026-04-30', 1269, 921, 33, null),
('2026-05-07', 1285, 926, 33, null),
('2026-05-14', 1307, 926, 33, null),
('2026-05-21', 1317, 930, 33, null),
('2026-05-28', 1331, 937, 36, null),
('2026-06-04', 1343, 937, 37, null),
('2026-06-11', 1352, 940, 37, null),
('2026-06-18', 1365, 961, 37, null),
('2026-06-25', 1376, 970, 39, null),
('2026-07-02', 1385, 972, 42, null),
('2026-07-09', 1384, 983, 47, null)
on conflict (week_date) do nothing;
