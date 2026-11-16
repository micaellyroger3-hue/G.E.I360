import { withSupabase } from "npm:@supabase/server@1.9.2";

const APP_ORIGIN = "https://micaellyroger3-hue.github.io";
const APP_REDIRECT = "https://micaellyroger3-hue.github.io/G.E.I360/";

Deno.serve(
  withSupabase({
    auth: "user",
    cors: {
      headers: {
        "Access-Control-Allow-Origin": APP_ORIGIN,
        "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Vary": "Origin",
      },
    },
  }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "Método não permitido." }, { status: 405 });
    }

    try {
      const { supabase, supabaseAdmin, userClaims } = ctx;
      const callerId = userClaims?.id;
      const callerEmail = userClaims?.email?.toLowerCase() || "";
      if (!callerId) return Response.json({ error: "Sessão inválida." }, { status: 401 });

      let body: Record<string, unknown>;
      try {
        body = await req.json();
      } catch {
        return Response.json({ error: "Dados do convite inválidos." }, { status: 400 });
      }

      const companyId = typeof body.company_id === "string" ? body.company_id.trim() : "";
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      const fullName = typeof body.full_name === "string" ? body.full_name.trim().slice(0, 120) : "";

      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId)) {
        return Response.json({ error: "Empresa inválida." }, { status: 400 });
      }
      if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        return Response.json({ error: "Informe um e-mail válido." }, { status: 400 });
      }
      if (callerEmail === email) {
        return Response.json({ error: "Você já faz parte desta empresa." }, { status: 400 });
      }

      const { data: membership, error: membershipError } = await supabase
        .from("company_members")
        .select("role,status")
        .eq("company_id", companyId)
        .eq("user_id", callerId)
        .maybeSingle();

      if (membershipError) {
        return Response.json({ error: "Não foi possível validar sua permissão." }, { status: 403 });
      }
      if (!membership || membership.status !== "active" || !["owner", "admin"].includes(membership.role)) {
        return Response.json({ error: "Somente proprietário ou administrador pode convidar funcionários." }, { status: 403 });
      }

      let existingUser: { id: string; email?: string; email_confirmed_at?: string | null } | null = null;
      for (let page = 1; page <= 100; page++) {
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error) {
          return Response.json({ error: "Não foi possível verificar a conta do funcionário." }, { status: 502 });
        }
        const users = data?.users || [];
        existingUser = users.find((item) => item.email?.toLowerCase() === email) || null;
        if (existingUser || users.length < 1000) break;
      }

      const targetUserId = existingUser?.id;
      if (targetUserId) {
        if (!existingUser?.email_confirmed_at) {
          return Response.json({ error: "Este e-mail já possui cadastro, mas ainda não foi confirmado. Peça para concluir o cadastro antes de vinculá-lo." }, { status: 409 });
        }
        const { data: prior, error: priorError } = await supabaseAdmin
          .from("company_members")
          .select("id,status")
          .eq("company_id", companyId)
          .eq("user_id", targetUserId)
          .maybeSingle();
        if (priorError) {
          return Response.json({ error: "Não foi possível verificar o vínculo existente." }, { status: 502 });
        }
        if (prior?.status === "active") {
          return Response.json({ error: "Este usuário já está vinculado à empresa." }, { status: 409 });
        }
      }

      let invitedUserId = targetUserId;
      let invitationSent = false;
      if (!invitedUserId) {
        const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
          data: fullName ? { full_name: fullName } : {},
          redirectTo: APP_REDIRECT,
        });
        if (inviteError || !inviteData?.user?.id) {
          return Response.json({ error: "Não foi possível enviar o convite. Confira o serviço de e-mail do projeto e tente novamente." }, { status: 502 });
        }
        invitedUserId = inviteData.user.id;
        invitationSent = true;
      }

      const { error: upsertError } = await supabaseAdmin
        .from("company_members")
        .upsert({
          company_id: companyId,
          user_id: invitedUserId,
          role: "employee",
          status: "active",
        }, { onConflict: "company_id,user_id" });

      if (upsertError) {
        return Response.json({ error: "A conta foi localizada, mas não foi possível concluir o vínculo. Tente novamente; nenhum dado da empresa foi removido." }, { status: 500 });
      }

      return Response.json({
        ok: true,
        invitation_sent: invitationSent,
        existing_account_linked: !invitationSent,
        role: "employee",
      });
    } catch {
      return Response.json({ error: "Ocorreu um erro inesperado ao processar o convite." }, { status: 500 });
    }
  }),
);
