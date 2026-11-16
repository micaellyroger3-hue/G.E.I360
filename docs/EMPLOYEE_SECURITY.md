# Cadastro e convite seguro de funcionários — G.E.I360

## Ficha de funcionário
- A tabela `employees` mantém os dados de RH vinculados a `company_id`.
- A migration `employee_integrity` está aplicada: impede alterar a empresa de origem e o autor original do cadastro.
- A ficha continua separada da conta de autenticação; cadastrar uma ficha não cria login automaticamente.

## Convite de acesso
- Edge Function: `invite-company-member`.
- Estado no Supabase: **ACTIVE**, versão 4, com `verify_jwt=true`.
- A interface apresenta **Convidar acesso** nas fichas que possuem e-mail, somente para owner/admin.
- O convite exige confirmação explícita na tela e cria vínculo na empresa com papel inicial `employee`.
- O backend valida o JWT, confirma que o usuário atual é membro ativo da empresa e exige papel owner ou admin. Managers, employees e viewers não podem chamar o fluxo.
- Para um e-mail sem conta, usa `auth.admin.inviteUserByEmail`; o e-mail de convite é enviado somente quando o usuário confirma o envio na interface.
- Para uma conta já existente e com e-mail confirmado, cria o vínculo sem enviar outro convite. Conta já vinculada é recusada; conta existente sem e-mail confirmado não é vinculada.
- O convite é vinculado a `company_members` e fica ativo para que a pessoa possa acessar a empresa depois de aceitar o link e autenticar-se.
- O link de convite retorna ao aplicativo publicado. O app reconhece o tipo `invite`, pede que a pessoa defina sua senha e depois permite entrar normalmente.

## Segurança
- A função exige JWT válido e valida a associação e o papel no contexto do próprio usuário antes de usar privilégios administrativos.
- O middleware usa `SUPABASE_SECRET_KEYS` somente no contexto `supabaseAdmin` da Edge Function. Nenhuma chave administrativa é enviada ao navegador ou armazenada no repositório. O `verify_jwt` do gateway fica desativado para esta função porque a validação do JWT é feita pelo middleware `auth: user`.
- O papel atribuído por este fluxo é sempre `employee`; a função não permite criar owners ou admins.
- A função não altera fichas de outros funcionários nem dados operacionais da empresa.

## Validação e limites
- A Edge Function foi implantada e está ativa. A validação automatizada do repositório verifica o código, as permissões, a configuração de autenticação e a presença do fluxo no frontend.
- Nenhum convite de e-mail real foi enviado durante a implementação. A entrega do e-mail depende da configuração de SMTP e da lista de URLs de redirecionamento permitidas no Supabase Auth.
- A homologação final de envio/aceite deve ser feita com um endereço de e-mail de teste sob controle do proprietário. Não usar e-mails de terceiros sem autorização.
