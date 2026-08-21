// ============================================================
// WISE HEART PLANNER — weekly-sync Edge Function
//
// Deploy to Supabase as a function named exactly: weekly-sync
// (Dashboard > Edge Functions > Deploy a new function > paste this in)
//
// Runs every Thursday from the pg_cron job in supabase-update-3.sql,
// and can also be triggered by the "Sync now" button in the app.
//
// What it fills in automatically:
//   youtube_views    — exact, from the YouTube Data API
//   instagram        — exact follower count, from the Instagram Graph API
//   instagram_views  — last 7 days of views, added to the running total
//   youtube          — provisional: YouTube rounds subs to 3 significant
//                      figures, so this is a placeholder for you to correct
//   tiktok           — carried forward from last week (no API available)
//
// Rows it creates are flagged needs_review = true until you confirm them.
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

// ---------- date helpers (UTC, matching the app) ----------
function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}
function addDays(iso: string, n: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}
function lastThursday(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  const back = (new Date(Date.UTC(y, m - 1, d)).getUTCDay() - 4 + 7) % 7;
  return addDays(iso, -back);
}
function unixOf(iso: string): number {
  return Math.floor(new Date(iso + "T00:00:00Z").getTime() / 1000);
}

// ---------- YouTube ----------
async function fetchYouTube(apiKey: string, channelId: string) {
  const url = `https://www.googleapis.com/youtube/v3/channels?part=statistics&id=${encodeURIComponent(channelId)}&key=${apiKey}`;
  const res = await fetch(url);
  const json = await res.json();
  if (!res.ok) throw new Error(`YouTube API ${res.status}: ${json?.error?.message ?? "unknown error"}`);
  const stats = json?.items?.[0]?.statistics;
  if (!stats) throw new Error(`YouTube returned no channel for id "${channelId}" — check YOUTUBE_CHANNEL_ID (it should start with UC)`);
  return {
    subs: stats.hiddenSubscriberCount ? null : Number(stats.subscriberCount), // rounded by Google
    views: Number(stats.viewCount),                                            // exact
  };
}

// ---------- Instagram ----------
// Long-lived tokens last 60 days and can be refreshed after 24 hours.
// We refresh whenever ours is older than 30 days, so it never lapses.
async function refreshIgTokenIfStale(sb: any, token: string, issuedAt: string | null) {
  const ageDays = issuedAt ? (Date.now() - new Date(issuedAt).getTime()) / 86400000 : 999;
  if (ageDays < 30) return { token, refreshed: false };
  try {
    const res = await fetch(
      `https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=${token}`,
    );
    const json = await res.json();
    if (!res.ok || !json.access_token) throw new Error(json?.error?.message ?? `status ${res.status}`);
    await sb.from("wise_heart_config").upsert([
      { key: "ig_access_token", value: json.access_token, updated_at: new Date().toISOString() },
      { key: "ig_token_issued_at", value: new Date().toISOString(), updated_at: new Date().toISOString() },
    ]);
    return { token: json.access_token, refreshed: true };
  } catch (e) {
    // Not fatal — the current token probably still works today.
    console.error("IG token refresh failed:", e);
    return { token, refreshed: false, refreshError: String(e) };
  }
}

async function fetchInstagram(igUserId: string, token: string, sinceISO: string, untilISO: string) {
  // Follower count — exact
  const profRes = await fetch(
    `https://graph.facebook.com/v21.0/${igUserId}?fields=followers_count,username&access_token=${token}`,
  );
  const prof = await profRes.json();
  if (!profRes.ok) throw new Error(`Instagram profile ${profRes.status}: ${prof?.error?.message ?? "unknown error"}`);

  // Views over the window. Meta has moved this metric around, so try the
  // modern shape first and fall back to summing daily values.
  let views: number | null = null;
  const base = `https://graph.facebook.com/v21.0/${igUserId}/insights`;
  const range = `since=${unixOf(sinceISO)}&until=${unixOf(untilISO)}&access_token=${token}`;
  try {
    const r1 = await fetch(`${base}?metric=views&metric_type=total_value&period=day&${range}`);
    const j1 = await r1.json();
    const tv = j1?.data?.[0]?.total_value?.value;
    if (r1.ok && typeof tv === "number") views = tv;
  } catch (_) { /* fall through */ }
  if (views === null) {
    try {
      const r2 = await fetch(`${base}?metric=views&period=day&${range}`);
      const j2 = await r2.json();
      const vals = j2?.data?.[0]?.values;
      if (r2.ok && Array.isArray(vals)) {
        views = vals.reduce((s: number, v: any) => s + (Number(v.value) || 0), 0);
      }
    } catch (_) { /* leave null */ }
  }
  return { followers: Number(prof.followers_count), username: prof.username, windowViews: views };
}

// ---------- main ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const log: string[] = [];
  const warnings: string[] = [];
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body, null, 2), {
      status,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  try {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Optional overrides: {"week":"2026-08-20","dry":true}
    let body: any = {};
    try { body = await req.json(); } catch (_) { /* empty body is fine */ }
    const week = body.week ?? lastThursday(todayISO());
    const dry = body.dry === true;

    // Previous row — for carrying TikTok forward and accumulating IG views
    const { data: prevRows } = await sb
      .from("weekly_stats").select("*")
      .lt("week_date", week).order("week_date", { ascending: false }).limit(1);
    const prev = prevRows?.[0] ?? null;

    // Existing row for this week, if the form or an earlier run made one
    const { data: curRows } = await sb
      .from("weekly_stats").select("*").eq("week_date", week).limit(1);
    const cur = curRows?.[0] ?? null;

    const row: Record<string, unknown> = {
      week_date: week,
      auto_at: new Date().toISOString(),
      needs_review: true,
    };

    // ---- YouTube ----
    const ytKey = Deno.env.get("YOUTUBE_API_KEY");
    const ytChannel = Deno.env.get("YOUTUBE_CHANNEL_ID");
    if (ytKey && ytChannel) {
      try {
        const yt = await fetchYouTube(ytKey, ytChannel);
        row.youtube_views = yt.views;
        // Provisional: only use the rounded sub count if nothing better exists.
        row.youtube = cur?.youtube ?? yt.subs ?? prev?.youtube ?? 0;
        log.push(`YouTube: ${yt.views.toLocaleString()} views, ~${yt.subs?.toLocaleString() ?? "hidden"} subs (rounded)`);
      } catch (e) {
        // Don't let YouTube take Instagram down with it.
        warnings.push("YouTube failed: " + String(e instanceof Error ? e.message : e));
        row.youtube = cur?.youtube ?? prev?.youtube ?? 0;
        row.youtube_views = cur?.youtube_views ?? prev?.youtube_views ?? null;
      }
    } else {
      warnings.push("YOUTUBE_API_KEY / YOUTUBE_CHANNEL_ID not set — skipped YouTube");
      row.youtube = cur?.youtube ?? prev?.youtube ?? 0;
      row.youtube_views = cur?.youtube_views ?? prev?.youtube_views ?? null;
    }

    // ---- Instagram ----
    const igUserId = Deno.env.get("IG_USER_ID");
    if (igUserId) {
      const { data: cfg } = await sb.from("wise_heart_config").select("*");
      const cfgMap: Record<string, string> = {};
      (cfg ?? []).forEach((c: any) => { cfgMap[c.key] = c.value; });
      let token = cfgMap["ig_access_token"] ?? Deno.env.get("IG_ACCESS_TOKEN") ?? "";

      if (!token) {
        warnings.push("No Instagram token found in wise_heart_config or IG_ACCESS_TOKEN — skipped Instagram");
        row.instagram = cur?.instagram ?? prev?.instagram ?? 0;
        row.instagram_views = cur?.instagram_views ?? prev?.instagram_views ?? null;
      } else {
        const r = await refreshIgTokenIfStale(sb, token, cfgMap["ig_token_issued_at"] ?? null);
        token = r.token;
        if (r.refreshed) log.push("Instagram: access token refreshed for another 60 days");
        if (r.refreshError) warnings.push("IG token refresh failed: " + r.refreshError);

        try {
          const ig = await fetchInstagram(igUserId, token, addDays(week, -7), week);
          row.instagram = ig.followers;
          if (ig.windowViews === null) {
            warnings.push("Instagram views unavailable this run — carried the previous total forward");
            row.instagram_views = cur?.instagram_views ?? prev?.instagram_views ?? null;
          } else {
            // IG has no lifetime counter, so we keep a running total ourselves.
            const base = Number(prev?.instagram_views ?? 0);
            row.instagram_views = base + ig.windowViews;
            log.push(`Instagram: ${ig.followers.toLocaleString()} followers, +${ig.windowViews.toLocaleString()} views over 7 days`);
          }
        } catch (e) {
          warnings.push("Instagram failed: " + String(e instanceof Error ? e.message : e));
          row.instagram = cur?.instagram ?? prev?.instagram ?? 0;
          row.instagram_views = cur?.instagram_views ?? prev?.instagram_views ?? null;
        }
      }
    } else {
      warnings.push("IG_USER_ID not set — skipped Instagram");
      row.instagram = cur?.instagram ?? prev?.instagram ?? 0;
      row.instagram_views = cur?.instagram_views ?? prev?.instagram_views ?? null;
    }

    // ---- TikTok: no API available, carry last week's numbers forward ----
    row.tiktok = cur?.tiktok ?? prev?.tiktok ?? 0;
    row.tiktok_views = cur?.tiktok_views ?? prev?.tiktok_views ?? null;
    log.push("TikTok: carried forward — needs your number");

    if (cur?.notes) row.notes = cur.notes;

    if (dry) return json({ ok: true, dry: true, week, would_write: row, log, warnings });

    const { error } = await sb.from("weekly_stats")
      .upsert({ ...row, updated_at: new Date().toISOString() }, { onConflict: "week_date" });
    if (error) throw new Error("Database write failed: " + error.message);

    return json({ ok: true, week, wrote: row, log, warnings });
  } catch (err) {
    console.error(err);
    return json({ ok: false, error: String(err instanceof Error ? err.message : err), log, warnings }, 500);
  }
});
