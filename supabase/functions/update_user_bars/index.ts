import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData?.user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await req.json();
  const mode = body.mode; // "visit" | "nearby"
  const bar = body.bar;
  const distance_m = body.distance_m ?? null;

  if (!bar?.id || !mode) {
    return new Response("Missing bar or mode", { status: 400 });
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("visited_bars, nearby_bars")
    .eq("id", authData.user.id)
    .single();

  if (profileError) {
    return new Response(profileError.message, { status: 500 });
  }

  const visited = Array.isArray(profile.visited_bars) ? profile.visited_bars : [];
  const nearby = Array.isArray(profile.nearby_bars) ? profile.nearby_bars : [];
  const now = new Date().toISOString();

  const upsert = (arr: any[], item: any) => {
    const idx = arr.findIndex((b) => b.id === item.id);
    if (idx >= 0) arr[idx] = { ...arr[idx], ...item };
    else arr.push(item);
  };

  if (mode === "visit") {
    upsert(visited, { ...bar, last_visited_at: now });
  } else if (mode === "nearby") {
    upsert(nearby, { ...bar, distance_m, last_seen_at: now });
  }

  const { error: updateError } = await supabase
    .from("profiles")
    .update({ visited_bars: visited, nearby_bars: nearby })
    .eq("id", authData.user.id);

  if (updateError) {
    return new Response(updateError.message, { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
