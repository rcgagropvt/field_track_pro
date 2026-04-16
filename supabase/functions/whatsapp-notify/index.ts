// supabase/functions/whatsapp-notify/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const TWILIO_SID = Deno.env.get("TWILIO_ACCOUNT_SID")!;
const TWILIO_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN")!;
const TWILIO_FROM = Deno.env.get("TWILIO_WHATSAPP_FROM")!;

async function sendWhatsApp(to: string, message: string) {
  const body = new URLSearchParams({
    From: TWILIO_FROM,
    To: to,
    Body: message,
  });

  return await fetch(
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
}

serve(async (req) => {
  const { type, data } = await req.json();

  let message = "";
  let to = "";

  if (type === "order_created") {
    to = `whatsapp:+91${data.phone}`;
    message =
      `✅ *Order Confirmed!*\n\n` +
      `Dear ${data.party_name},\n` +
      `Your order of ₹${data.total} has been placed.\n` +
      `Order ID: ${data.order_id}\n\n` +
      `Thank you for your business! 🙏`;

  } else if (type === "visit_completed") {
    to = `whatsapp:+91${data.phone}`;
    message =
      `📍 *Visit Summary*\n\n` +
      `Dear ${data.party_name},\n` +
      `Thank you for meeting with us today.\n` +
      `Visit recorded at ${data.time}.\n\n` +
      `We look forward to serving you again!`;

  } else if (type === "payment_confirmed") {
    to = `whatsapp:+91${data.phone}`;
    message =
      `💰 *Payment Confirmed!*\n\n` +
      `Dear ${data.party_name},\n\n` +
      `We have confirmed receipt of your payment:\n\n` +
      `📋 Invoice: ${data.invoice_number}\n` +
      `💵 Amount: ₹${data.amount}\n` +
      `💳 Mode: ${data.payment_mode}\n` +
      `${data.reference_no ? `🔖 Ref: ${data.reference_no}\n` : ""}` +
      `✅ Your account has been updated.\n\n` +
      `Thank you! 🙏`;

  } else if (type === "payment_reminder") {
    to = `whatsapp:+91${data.phone}`;
    message =
      `🔔 *Payment Reminder*\n\n` +
      `Dear ${data.party_name},\n\n` +
      `This is a gentle reminder that you have an outstanding balance:\n\n` +
      `📋 Invoice: ${data.invoice_number}\n` +
      `💰 Outstanding: ₹${data.balance}\n` +
      `📅 Due Date: ${data.due_date}\n\n` +
      `Please arrange payment at the earliest.`;
  }

  if (!to || !message) {
    return new Response(JSON.stringify({ error: "Unknown type" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const resp = await sendWhatsApp(to, message);
  const result = await resp.json();

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
    status: resp.ok ? 200 : 500,
  });
});