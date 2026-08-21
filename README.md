# Wise Heart Content Planner

Weekly tracker for Wise Heart Connect — followers, views, and podcast pipeline.
Data lives in Supabase; this repo is just the front end.

## Files

| File | What it is |
|---|---|
| `index.html` | The whole app. One file. Deployed to Vercel. |
| `weekly-sync.ts` | Supabase Edge Function — pulls YouTube/Instagram numbers each Thursday |
| `supabase-setup.sql` | First-time database setup + spreadsheet import |
| `supabase-update-2.sql` | Adds view columns and the podcasts table |
| `supabase-update-3.sql` | Adds auto-sync columns and the weekly schedule |
| `AUTOMATION-GUIDE.md` | How the automatic syncing was set up |
| `SETUP-GUIDE.md` | Original Supabase + hosting setup |

## Updating the live site

Once this repo is connected to Vercel, pushing a change to `main` redeploys
automatically — no drag-and-drop needed.

## Note on keys

`index.html` contains the Supabase **publishable** key. That one is safe to be
public — it only reaches tables with open policies (`weekly_stats`, `podcasts`).
The service-role key and the YouTube API key live in Supabase secrets and must
never be committed here.
