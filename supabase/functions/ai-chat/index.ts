import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.0-flash",
  "gemini-2.0-flash-lite",
];

async function callGemini(
  prompt: string
): Promise<{ answer: string; model: string }> {
  for (const model of MODELS) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_KEY}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1500,
            topP: 0.9,
          },
          safetySettings: [
            {
              category: "HARM_CATEGORY_HARASSMENT",
              threshold: "BLOCK_NONE",
            },
            {
              category: "HARM_CATEGORY_HATE_SPEECH",
              threshold: "BLOCK_NONE",
            },
            {
              category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              threshold: "BLOCK_NONE",
            },
            {
              category: "HARM_CATEGORY_DANGEROUS_CONTENT",
              threshold: "BLOCK_NONE",
            },
          ],
        }),
      });

      if (res.ok) {
        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) return { answer: text, model };
      }

      const errData = await res.json().catch(() => ({}));
      const errMsg = errData?.error?.message || "";
      console.log(
        `Model ${model} failed (${res.status}): ${errMsg.substring(0, 100)}`
      );

      if (res.status !== 429 && res.status !== 404 && res.status !== 400) {
        return { answer: `API error: ${errMsg}`, model };
      }
    } catch (e) {
      console.log(`Model ${model} exception: ${e.message}`);
    }
  }
  return {
    answer:
      "All AI models are currently unavailable. Please try again in a few minutes.",
    model: "none",
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { question } = await req.json();
    if (!question) {
      return new Response(JSON.stringify({ error: "No question provided" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // Use service role — bypasses JWT verification entirely
    const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const now = new Date();
    const monthStart = new Date(
      now.getFullYear(),
      now.getMonth(),
      1
    ).toISOString();

    const [
      { data: employees },
      { data: visitsThisMonth },
      { data: ordersThisMonth },
      { data: anomalies },
      { data: partyHealth },
      { data: attendance },
      { data: parties },
      { data: loyaltyTiers },
      { data: expenses },
    ] = await Promise.all([
      sb
        .from("profiles")
        .select("id, full_name, email, role, is_active")
        .eq("role", "employee"),
      sb
        .from("visits")
        .select(
          "id, user_id, party_name, status, check_in_time, duration_minutes, purpose, outcome, geofence_status"
        )
        .gte("check_in_time", monthStart),
      sb
        .from("orders")
        .select(
          "id, user_id, party_name, total_amount, net_amount, status, created_at"
        )
        .gte("created_at", monthStart),
      sb
        .rpc("ai_detect_anomalies")
        .then((r: any) => ({ data: r.data }))
        .catch(() => ({ data: [] })),
      sb
        .rpc("ai_party_health_scores")
        .then((r: any) => ({ data: r.data }))
        .catch(() => ({ data: [] })),
      sb
        .from("attendance")
        .select("id, user_id, check_in_time, check_out_time, status")
        .gte("check_in_time", monthStart),
      sb
        .from("parties")
        .select(
          "id, name, type, city, outstanding_balance, is_active"
        ),
      sb
        .from("loyalty_tiers")
        .select(
          "party_id, tier, total_points, total_purchases, points_redeemed"
        )
        .then((r: any) => ({ data: r.data }))
        .catch(() => ({ data: [] })),
      sb
        .from("expenses")
        .select("id, user_id, amount, category, status, created_at")
        .gte("created_at", monthStart),
    ]);

    const empSummary = (employees || []).map((emp: any) => {
      const empVisits = (visitsThisMonth || []).filter(
        (v: any) => v.user_id === emp.id
      );
      const empOrders = (ordersThisMonth || []).filter(
        (o: any) => o.user_id === emp.id
      );
      const empAttendance = (attendance || []).filter(
        (a: any) => a.user_id === emp.id
      );
      const completedVisits = empVisits.filter(
        (v: any) => v.status === "completed"
      );
      const ghostVisits = empVisits.filter(
        (v: any) => v.duration_minutes && v.duration_minutes < 2
      );
      const geofenceBreaches = empVisits.filter(
        (v: any) => v.geofence_status === "outside"
      );
      const totalRevenue = empOrders.reduce(
        (s: number, o: any) =>
          s + (Number(o.net_amount) || Number(o.total_amount) || 0),
        0
      );
      return {
        name: emp.full_name,
        active: emp.is_active,
        total_visits: empVisits.length,
        completed_visits: completedVisits.length,
        ghost_visits: ghostVisits.length,
        geofence_breaches: geofenceBreaches.length,
        orders: empOrders.length,
        revenue: Math.round(totalRevenue),
        attendance_days: empAttendance.length,
        avg_visit_duration:
          completedVisits.length > 0
            ? Math.round(
                completedVisits.reduce(
                  (s: number, v: any) => s + (v.duration_minutes || 0),
                  0
                ) / completedVisits.length
              )
            : 0,
      };
    });

    const partySummary = (parties || []).slice(0, 30).map((p: any) => {
      const pVisits = (visitsThisMonth || []).filter(
        (v: any) => v.party_name === p.name
      );
      const pOrders = (ordersThisMonth || []).filter(
        (o: any) => o.party_name === p.name
      );
      const loyalty = (loyaltyTiers || []).find(
        (lt: any) => lt.party_id === p.id
      );
      return {
        name: p.name,
        type: p.type,
        city: p.city,
        outstanding: Number(p.outstanding_balance) || 0,
        visits_this_month: pVisits.length,
        orders_this_month: pOrders.length,
        loyalty_tier: loyalty?.tier || "none",
        loyalty_points: loyalty?.total_points || 0,
      };
    });

    const anomalySummary = (anomalies || [])
      .slice(0, 20)
      .map((a: any) => ({
        type: a.anomaly_type,
        severity: a.severity,
        title: a.title,
        description: a.description,
        user: a.user_name,
      }));

    const healthSummary = (partyHealth || [])
      .slice(0, 20)
      .map((p: any) => ({
        party: p.out_party_name,
        score: p.out_health_score,
        risk: p.out_risk_level,
        days_since_visit: p.out_days_since_visit,
        visit_trend: p.out_visit_trend,
        order_trend: p.out_order_trend,
      }));

    const context = JSON.stringify({
      date: now.toISOString().split("T")[0],
      month: now.toLocaleString("default", {
        month: "long",
        year: "numeric",
      }),
      employee_performance: empSummary,
      party_summary: partySummary,
      anomalies: anomalySummary,
      party_health: healthSummary,
      totals: {
        total_visits: (visitsThisMonth || []).length,
        total_orders: (ordersThisMonth || []).length,
        total_revenue: (ordersThisMonth || []).reduce(
          (s: number, o: any) =>
            s +
            (Number(o.net_amount) || Number(o.total_amount) || 0),
          0
        ),
        total_parties: (parties || []).length,
        total_expenses: (expenses || []).reduce(
          (s: number, e: any) => s + (Number(e.amount) || 0),
          0
        ),
      },
    });

    const prompt = `You are Vartmaan AI, an intelligent field sales operations analyst for a distribution/FMCG company in India. You have access to real-time business data.

Your job:
- Answer admin questions about team performance, visits, orders, revenue, anomalies, party health, attendance, expenses, and loyalty.
- Be specific: use names, numbers, percentages from the data.
- Flag concerns proactively (ghost visits, low attendance, declining parties).
- Give actionable recommendations.
- Use Indian Rupee (₹) for currency.
- Keep responses concise but insightful. Use bullet points for lists.
- If data is insufficient to answer, say so honestly.
- NEVER make up data. Only use what's provided in the context.

Current business data:
${context}

Admin question: ${question}`;

    const { answer, model } = await callGemini(prompt);

    return new Response(
      JSON.stringify({
        answer,
        model_used: model,
        context_summary: {
          employees: empSummary.length,
          parties: partySummary.length,
          anomalies: anomalySummary.length,
        },
      }),
      {
        headers: {
          ...CORS_HEADERS,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (e) {
    console.error("AI Chat error:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
