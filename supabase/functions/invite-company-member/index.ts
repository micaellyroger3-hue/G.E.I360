import { createClient } from "npm:@supabase/supabase-js@2.95.0";

const APP_ORIGIN = "https://micaellyroger3-hue.github.io";
const APP_REDIRECT = "https://micaellyroger3-hue.github.io/G.E.I360/";
const corsHeaders = {
  "Access-Control-Allow-Origin": APP_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405);

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!token) return json({ error: "Sessão não encontrada. Entre novamente." }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const publishableRaw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
    const secretRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
    const publishable = publishableRaw ? JSON.parse(publishableRaw).default : Deno.env.get("SUPABASE_ANON_KEY");
    const secret = secretRaw ? JSON.parse(secretRaw).default : Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !publishable || !secret) {
      return json({ error: "Configuração segura do serviço indisponível." }, 500);
    }

    const userClient = createClient(url, publishable, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const adminClient = createClient(url, secret, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    const caller = userData?.user;
    if (userError || !caller) return json({ error: "Sessão inválida. Entre novamente." }, 401);

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Dados do convite inválidos." }, 400);
    }

    const companyId = typeof body.company_id === "string" ? body.company_id.trim() : "";
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const fullName = typeof body.full_name === "string" ? body.full_name.trim().slice(0, 120) : "";

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId)) {
      return json({ error: "Empresa inválida." }, 400);
    }
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "Informe um e-mail válido." }, 400);
    }
    if (caller.email?.toLowerCase() === email) {
      return json({ error: "Você já faz parte desta empresa." }, 400);
    }

    const { data: membership, error: membershipError } = await userClient
      .from("company_members")
      .select("role,status")
      .eq("company_id", companyId)
      .eq("user_id", caller.id)
      .maybeSingle();

    if (membershipError) return json({ error: "Não foi possível validar sua permissão." }, 403);
    if (!membership || membership.status !== "active" || !["owner", "admin"].includes(membership.role)) {
      return json({ error: "Somente proprietário ou administrador pode convidar funcionários." }, 403);
    }

    let existingUser: { id: string; email?: string; email_confirmed_at?: string | null } | null = null;
    for (let page = 1; page <= 100; page++) {
      const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) return json({ error: "Não foi possível verificar a conta do funcionário." }, 502);
      const users = data?.users || [];
      existingUser = users.find((item) => item.email?.toLowerCase() === email) || null;
      if (existingUser || users.length < 1000) break;
    }

    const targetUserId = existingUser?.id;
    if (targetUserId) {
      if (!existingUser?.email_confirmed_at) {
        return json({ error: "Este e-mail já possui cadastro, mas ainda não foi confirmado. Peça para concluir o cadastro antes de vinculá-lo." }, 409);
      }
      const { data: prior, error: priorError } = await adminClient
        .from("company_members")
        .select("id,status")
        .eq("company_id", companyId)
        .eq("user_id", targetUserId)
        .maybeSingle();
      if (priorError) return json({ error: "Não foi possível verificar o vínculo existente." }, 502);
      if (prior?.status === "active") return json({ error: "Este usuário já está vinculado à empresa." }, 409);
    }

    let invitedUserId = targetUserId;
    let invitationSent = false;
    if (!invitedUserId) {
      const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
        data: fullName ? { full_name: fullName } : {},
        redirectTo: APP_REDIRECT,
      });
      if (inviteError || !inviteData?.user?.id) {
        return json({ error: "Não foi possível enviar o convite. Confira o serviço de e-mail do projeto e tente novamente." }, 502);
      }
      invitedUserId = inviteData.user.id;
      invitationSent = true;
    }

    const { error: upsertError } = await adminClient
      .from("company_members")
      .upsert({
        company_id: companyId,
        user_id: invitedUserId,
        role: "employee",
        status: "active",
      }, { onConflict: "company_id,user_id" });

    if (upsertError) {
      return json({ error: "A conta foi localizada, mas não foi possível concluir o vínculo. Tente novamente; nenhum dado da empresa foi removido." }, 500);
    }

    return json({
      ok: true,
      invitation_sent: invitationSent,
      existing_account_linked: !invitationSent,
      role: "employee",
    });
  } catch {
    return json({ error: "Ocorreu um erro inesperado ao processar o convite." }, 500);
  }
});
