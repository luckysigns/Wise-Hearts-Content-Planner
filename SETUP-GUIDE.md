# Wise Heart Planner — Setup Guide

Two pieces make this work:

- **Supabase** holds your numbers (the database). This is what makes it sync everywhere.
- **Vercel** shows the app (one HTML file). Free, drag-and-drop.

About 10 minutes total, one time. No logins after that.

## Part 1 — Supabase (the data)

1. Go to **supabase.com** → sign up free → **New project**. Name it anything (e.g. `wise-heart`). Set any database password — you won't need it again.
2. Wait ~1 minute for the project to spin up.
3. In the left sidebar, open **SQL Editor**.
4. Open `supabase-setup.sql` (came with this app) in any text editor, copy **everything**, paste it into the SQL Editor, press **Run**.
   - This creates the table, opens access so no login is needed, and imports **all 72 weeks** from your spreadsheet (Feb 27, 2025 → Jul 9, 2026).
5. Go to **Project Settings → API** and keep this page open — you need two things from it:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon public** key (a long string starting with `eyJ...`)

## Part 2 — Put your keys in the app

1. Open `index.html` in a plain text editor (TextEdit on Mac — use Format → Make Plain Text; Notepad on Windows).
2. Near the top of the `<script>` section find:
   ```
   const SUPABASE_URL      = "PASTE_YOUR_SUPABASE_URL_HERE";
   const SUPABASE_ANON_KEY = "PASTE_YOUR_SUPABASE_ANON_KEY_HERE";
   ```
3. Replace the placeholder text with your Project URL and anon key (keep the quotes). Save.

*(Skipping this step is fine — the app will ask for the same two values on screen instead, but then you enter them once per device. Pasting them into the file means zero setup on every device.)*

## Part 3 — Vercel (the app's home)

1. Go to **vercel.com/drop** (sign up free if asked).
2. Drag `index.html` onto the page, name the project (e.g. `wise-heart-planner`), press **Deploy**.
3. You'll get a link like `wise-heart-planner.vercel.app` — **that's your app**. Open it anywhere: laptop, phone, Hilarey's phone. Bookmark it / add to home screen.

## Every Thursday from now on

Open the link → the form is pre-filled with last week's numbers → type the new counts → **Save week**. That's it. Every stat, average, and chart updates instantly, on every device.

## Good to know

- **No logins** means anyone who has the link *and* pokes around can edit the data. Just don't post the link publicly.
- **Fixing mistakes:** click *edit* next to any week in the History table — you can update or delete it.
- **Your spreadsheet's date typos** (weeks entered as 2016) were fixed during import; every week is a proper Thursday.
- **Updating the app later:** data lives in Supabase, so the app file rarely needs touching. If it ever does, drop the new file on vercel.com/drop again (it creates a fresh link).
- Free plans note: Supabase pauses projects after ~1 week of inactivity, but your weekly check-in counts as activity, so you're fine. If you ever skip a month and the app won't load, just log into supabase.com and click **Restore**.
