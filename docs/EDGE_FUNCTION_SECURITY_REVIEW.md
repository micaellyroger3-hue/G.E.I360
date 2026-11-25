# Revisão de segurança — Edge Function invite-company-member

**Data:** 25/11/2026  
**Escopo:** leitura do código atualmente implantado no Supabase (versão 5). Nenhuma implantação ou alteração de banco foi feita.

## Controles observados

- A função está ativa e exige JWT (`verify_jwt: true`).
- O wrapper usa contexto autenticado (`auth: "user"`).
- Exige usuário chamador identificado e valida o vínculo dele com a empresa.
- Apenas membros com status `active` e papel `owner` ou `admin` podem convidar.
- Valida UUID da empresa, formato/tamanho do e-mail e limita o nome.
- O papel atribuído ao novo vínculo é fixo como `employee`; o chamador não escolhe papel privilegiado.
- A resposta não expõe dados de conta; erros são genéricos.
- O acesso administrativo é usado após a autorização do chamador.

## Pontos para melhoria antes de escala

1. **Busca de usuários:** a função percorre páginas de até 1.000 usuários até 100 páginas para localizar o e-mail. Em projetos grandes isso pode ficar lento e consumir cotas. Planejar uma estratégia de convite/identificação sem varrer até 100 mil contas por solicitação.
2. **Convite e ativação:** o vínculo em `company_members` é gravado como `active` logo após disparar o convite. A pessoa ainda precisa confirmar o e-mail para autenticar, e as políticas exigem vínculo ativo. Ainda assim, um estado explícito `pending` com ativação após aceite seria mais claro, mas requer desenho do fluxo e compatibilidade com as telas e policies atuais.
3. **Limite de tentativas:** não foi identificado rate limit específico por empresa/usuário/e-mail na função. Avaliar limite de convites e proteção contra abuso antes de abrir para muitos clientes.
4. **CORS:** o cabeçalho permite a origem principal do GitHub Pages. CORS não substitui autenticação/autorização; os controles JWT e membership permanecem essenciais.

## Decisão

Não alterei o código implantado nem as políticas. Os pontos 1–3 são melhorias recomendadas, não prova de bypass de autorização no fluxo revisado. Antes de mudar o status para `pending`, é necessário planejar o aceite e revisar as telas/policies para não bloquear funcionários legítimos.
