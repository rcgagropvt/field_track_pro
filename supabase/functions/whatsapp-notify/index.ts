// supabase/functions/whatsapp-notify/index.ts
// Deploy: supabase functions deploy whatsapp-notify

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const TWILIO_SID = Deno.env.get("TWILIO_ACCOUNT_SID")!;
const TWILIO_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN")!;
const TWILIO_FROM = Deno.env.get("TWILIO_WHATSAPP_FROM")!; // whatsapp:+14155238886

serve(async (req) => {
  const { type, data } = await req.json();

  let message = "";
  let to = "";

  if (type === "order_created") {
    to = `whatsapp:+91${data.phone}`;
    message = `✅ *Order Confirmed!*\n\nDear ${data.party_name},\nYour order of ₹${data.total} has been placed.\nOrder ID: ${data.order_id}\n\nThank you for your business! 🙏`;
  } else if (type === "visit_completed") {
    to = `whatsapp:+91${data.phone}`;
    message = `📍 *Visit Summary*\n\nDear ${data.party_name},\nThank you for meeting with us today.\nVisit recorded at ${data.time}.\n\nWe look forward to serving you again!`;
  }

  if (!to || !message) {
    return new Response(JSON.stringify({ error: "Unknown type" }), { status: 400 });
  }

  const body = new URLSearchParams({ From: TWILIO_FROM, To: to, Body: message });
  const resp = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${TWILIO_SID}:${TWILIO_TOKEN}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    }
  );

  const result = await resp.json();
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
    status: resp.ok ? 200 : 500,
  });
});
