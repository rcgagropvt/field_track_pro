import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const textEncoder = new TextEncoder();
  const signingInput = textEncoder.encode(`${header}.${payload}`);

  // Import private key
  const pemContent = sa.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    signingInput
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const jwt = `${header}.${payload}.${sig}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

serve(async (req) => {
  try {
    const { user_id, user_ids, title, body, data } = await req.json();

    const saJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!saJson) {
      return new Response(JSON.stringify({ error: "FCM_SERVICE_ACCOUNT not set" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const sa: ServiceAccount = JSON.parse(saJson);
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get FCM tokens
    let tokens: string[] = [];

    if (user_ids && user_ids.length > 0) {
      const { data: profiles } = await supabase
        .from("profiles")
        .select("fcm_token")
        .in_("id", user_ids)
        .not("fcm_token", "is", null);
      tokens = (profiles || []).map((p: any) => p.fcm_token).filter(Boolean);
    } else if (user_id) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", user_id)
        .single();
      if (profile?.fcm_token) tokens = [profile.fcm_token];
    }

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no tokens" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken(sa);

    // Send via FCM v1 API
    let sent = 0;
    const errors: string[] = [];

    for (const token of tokens) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: token,
              notification: {
                title: title,
                body: body,
              },
              data: data || {},
              android: {
                priority: "high",
                notification: {
                  sound: "default",
                  channel_id: "fieldtrack_high",
                },
              },
            },
          }),
        }
      );

      if (res.ok) {
        sent++;
      } else {
        const errBody = await res.text();
        errors.push(errBody);
      }
    }

    return new Response(
      JSON.stringify({ sent, total: tokens.length, errors }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
