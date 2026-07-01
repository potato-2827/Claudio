// ============================================================
//  Resumen diario de vencimientos por email — "Mis Tareas"
//  Supabase Edge Function (Deno / TypeScript).
//
//  Qué hace, una vez por día (la dispara un cron, ver Parte 4):
//   1. Lee todas las filas de public.user_data.
//   2. Para cada usuario con la preferencia emailNotif = true,
//      calcula sus tareas vencidas y las que vencen HOY.
//   3. Si hay alguna, le manda un email (vía Resend) a la
//      dirección de su cuenta.
//
//  Secrets que usa (se configuran en Supabase):
//   - RESEND_API_KEY            -> tu clave de Resend (la cargás vos)
//   - SUPABASE_URL              -> la inyecta Supabase sola
//   - SUPABASE_SERVICE_ROLE_KEY -> la inyecta Supabase sola
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Zona horaria para calcular "hoy" (Argentina). Cambiá esto si hace falta.
const TZ = "America/Argentina/Buenos_Aires";

// Remitente. onboarding@resend.dev funciona sin dominio propio
// (y permite enviarte a tu propia cuenta de Resend).
const FROM = "Mis Tareas <onboarding@resend.dev>";

// "Hoy" como YYYY-MM-DD en la zona horaria elegida (en-CA da ese formato).
function todayInTZ(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(new Date());
}

// dd/mm/aa para mostrar en el mail
function fmt(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}/${m}/${y.slice(2)}`;
}

function esc(s: string): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!)
  );
}

interface Task { text?: string; due?: string | null; done?: boolean; }

function buildHtml(overdue: Task[], dueToday: Task[]): string {
  const li = (t: Task, withDate: boolean) =>
    `<li style="margin:4px 0">${esc(t.text || "(sin título)")}` +
    (withDate && t.due ? ` <span style="color:#888">— vencía ${fmt(t.due)}</span>` : "") +
    `</li>`;
  let s = `<div style="font-family:Segoe UI,Arial,sans-serif;max-width:520px;margin:0 auto;color:#181527">
    <h2 style="color:#5457e6">📋 Mis Tareas — recordatorio</h2>`;
  if (overdue.length) {
    s += `<h3 style="color:#dc2626;margin-bottom:4px">⚠️ Vencidas (${overdue.length})</h3>
      <ul style="margin-top:0">${overdue.map((t) => li(t, true)).join("")}</ul>`;
  }
  if (dueToday.length) {
    s += `<h3 style="color:#b45309;margin-bottom:4px">⏰ Vencen hoy (${dueToday.length})</h3>
      <ul style="margin-top:0">${dueToday.map((t) => li(t, false)).join("")}</ul>`;
  }
  s += `<p style="margin-top:18px"><a href="https://claudio-bice.vercel.app"
      style="background:#5457e6;color:#fff;text-decoration:none;padding:9px 16px;border-radius:8px;font-weight:600">
      Abrir Mis Tareas</a></p>
    <p style="color:#999;font-size:12px;margin-top:18px">
      Recibís esto porque activaste el aviso por email en Mis Tareas.
      Para dejar de recibirlo, desactivá el botón 🔔 en la app.</p></div>`;
  return s;
}

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
    const today = todayInTZ();

    // Mapa user_id -> email (requiere service role)
    const { data: usersList, error: usersErr } =
      await supabase.auth.admin.listUsers({ perPage: 1000 });
    if (usersErr) throw usersErr;
    const emailById = new Map(
      (usersList?.users || []).map((u) => [u.id, u.email as string | undefined])
    );

    const { data: rows, error } = await supabase
      .from("user_data")
      .select("user_id, data");
    if (error) throw error;

    let sent = 0, skipped = 0;
    for (const row of rows || []) {
      const d = (row.data || {}) as { emailNotif?: boolean; tasks?: Task[]; lists?: { tasks?: Task[] }[] };
      if (d.emailNotif !== true) { skipped++; continue; }
      // v3: junta las tareas de todas las listas; v2 (viejo): d.tasks suelto.
      const tasks: Task[] = Array.isArray(d.lists)
        ? d.lists.flatMap((l) => Array.isArray(l.tasks) ? l.tasks : [])
        : (Array.isArray(d.tasks) ? d.tasks : []);
      const overdue = tasks.filter((t) => t && !t.done && t.due && t.due < today);
      const dueToday = tasks.filter((t) => t && !t.done && t.due && t.due === today);
      if (overdue.length === 0 && dueToday.length === 0) { skipped++; continue; }

      const email = emailById.get(row.user_id);
      if (!email) { skipped++; continue; }

      const subject = `📋 Mis Tareas — ${overdue.length} vencida(s) y ${dueToday.length} para hoy`;
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ from: FROM, to: email, subject, html: buildHtml(overdue, dueToday) }),
      });
      if (res.ok) sent++; else console.error("Resend error", await res.text());
    }

    return new Response(JSON.stringify({ ok: true, today, sent, skipped }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
