# Automatic weekly sync — setup

When this is done, every Thursday at ~1am Portland time your Supabase fetches the numbers on its own and writes the week's row. You open the app when you feel like it, correct two numbers, done.

**What gets filled in automatically**

| Number | Source | Accuracy |
|---|---|---|
| YouTube views | YouTube Data API | Exact |
| Instagram followers | Instagram Graph API | Exact |
| Instagram views | Instagram Graph API | Exact (7-day total, added to your running count) |
| YouTube subscribers | YouTube Data API | **Rounded to the nearest 10** — correct it in the app |
| TikTok followers | *No API exists* | Carried forward — type the real number |
| TikTok views | *No API exists* | Carried forward — type the real number |

Set aside about 30 minutes — Part 1 is already done.

---

## Part 1 — YouTube key ✅ ALREADY DONE

You set this up for the creator scraper, and it's live and working. Your existing key is in:

```
Claude/CreatorApps/creatorapps-site/cerator scraper/.env
```

Tested it against your channel — the key is valid and YouTube Data API v3 is enabled on that project. Here are the two values you'll paste into Supabase in Part 4:

| Secret name | Value |
|---|---|
| `YOUTUBE_API_KEY` | the `AIza…` key from that `.env` file |
| `YOUTUBE_CHANNEL_ID` | `UC9EZs-J9cPYn0ZTBkdCBK9A` |

For reference, what the API returns for your channel right now:

- **215,768** lifetime views
- **1,420** subscribers *(rounded — the exact number is somewhere between 1,415 and 1,424)*
- **465** videos published

Two bits of housekeeping while you're in there, neither urgent:

- That key also sits in `Archive/astro_outreach/config.json` and, less ideally, in `cerator scraper/scraper_stderr.log`. Worth deleting the log line if you ever share that folder.
- In **console.cloud.google.com → APIs & Services → Credentials**, check the key is restricted to *YouTube Data API v3* under **API restrictions**. If it's unrestricted, anyone who found it could spend your quota on other Google services.

> **Never put this key in `index.html`.** That file gets published to Vercel where anyone can read it. The key belongs only in Supabase secrets, which stay server-side.

---

## Part 2 — Instagram access (25 min)

Instagram only opens its API to **Business** or **Creator** accounts. Personal accounts get nothing.

**First, confirm the account type:** Instagram app → your profile → menu (☰) → *Settings and privacy* → *Account type and tools*. If it says "Switch to professional account," tap it and pick **Creator**. It's free, reversible, and doesn't change how your profile looks to anyone.

Then:

1. Go to **developers.facebook.com** → log in → **My Apps** → **Create App**.
2. Pick use case **Other** → type **Business** → name it `Wise Heart Planner`.
3. In the app dashboard, find **Instagram** in the product list → **Set up**.
4. Open **Instagram → API setup with Instagram login** (or *Generate access tokens*), connect your Instagram account when prompted, and approve the permissions — you need at least `instagram_business_basic` and `instagram_business_manage_insights`.
5. Copy two things:
   - The **access token** (a long string)
   - Your **Instagram user ID** (a long number, shown on the same screen)

That token lasts 60 days, and the sync function refreshes it automatically every 30 days from here on — so this is a one-time job as long as the sync keeps running.

---

## Part 3 — Database prep (2 min)

In Supabase → **SQL Editor**, paste and run **`supabase-update-3.sql`**, but only the top section for now — stop before the part labelled *THE WEEKLY SCHEDULE*. You'll come back for that in Part 5.

---

## Part 4 — Deploy the sync function (10 min)

1. Supabase → left menu → **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Name it exactly `weekly-sync` (the name matters — the app and the schedule both call it by name).
3. Delete the sample code, paste in everything from **`weekly-sync.ts`**, and **Deploy**.
4. Now add the credentials. Still in Edge Functions, open **Secrets** (or *Manage secrets*) and add:

   | Name | Value |
   |---|---|
   | `YOUTUBE_API_KEY` | the `AIza…` key from `cerator scraper/.env` |
   | `YOUTUBE_CHANNEL_ID` | `UC9EZs-J9cPYn0ZTBkdCBK9A` |
   | `IG_USER_ID` | the Instagram user ID from Part 2 |
   | `IG_ACCESS_TOKEN` | the Instagram token from Part 2 |

   Skip the two `IG_` rows if you're not doing Instagram yet — the function just reports that it skipped Instagram and carries on.

5. **Test it.** Open your app and click **Sync now** in the top right. Within a few seconds you should see this week's numbers appear with a *check* tag. If something's off, Supabase → Edge Functions → `weekly-sync` → **Logs** shows exactly which step failed.

---

## Part 5 — Turn on the schedule (3 min)

1. Open `supabase-update-3.sql` again and scroll to *THE WEEKLY SCHEDULE*.
2. Replace the two placeholders:
   - `PROJECT_REF` → the bit from your URL: `ywjtbzxfdudrqsvsslzs`
   - `SERVICE_KEY` → Supabase → **Project Settings → API → service_role** key
3. Paste that section into the **SQL Editor** and run it.

> The service_role key is the powerful one. It's fine here — it lives inside your own database and never touches the app file or the internet. Don't paste it anywhere else.

Check it registered:

```sql
select jobname, schedule, active from cron.job;
```

---

## Your Thursday from now on

Open the app. A banner tells you the week arrived automatically. Click **Confirm the numbers**, fix the YouTube subscriber count (grab the exact figure from YouTube Studio) and the TikTok numbers, hit **Update week**. Roughly fifteen seconds.

If you forget, nothing breaks — the row is already saved with the accurate views. It just keeps the *check* tag until you get to it.

---

## When something goes wrong

**"No weekly-sync function deployed yet"** — the function name isn't exactly `weekly-sync`, or it didn't deploy. Re-check Part 4 step 2.

**YouTube says "no channel for id"** — you used the @handle instead of the `UC…` ID. Get the real one from YouTube Studio → Settings → Channel → Advanced.

**Instagram numbers stopped updating** — the token expired, which happens if the weekly sync didn't run for 60+ days. Redo Part 2 step 4 and update the `IG_ACCESS_TOKEN` secret.

**Nothing happened Thursday** — check the schedule ran:

```sql
select start_time, status, return_message
from cron.job_run_details order by start_time desc limit 10;
```

**See what the function would do without writing anything** — in Supabase → Edge Functions → `weekly-sync` → *Test*, send this body:

```json
{"dry": true}
```

It returns exactly what it would have written, plus a log of what it found and any warnings.
