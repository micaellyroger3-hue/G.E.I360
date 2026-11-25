# G.E.I360 — checklist de preparação para clientes

## Estado verificado em 25/11/2026

- PRs de segurança e navegação #31, #36, #37, #38, #40 e #41 integrados à branch main.
- CI de validação passou após as alterações.
- Supabase: 33/33 tabelas públicas com RLS habilitado.
- Políticas restritivas de módulo: 26 tabelas; desativar módulo bloqueia consultas REST diretas sem apagar registros.
- Grants legados nas sequências públicas de vendas/compras foram removidos: anon sem acesso; authenticated mantém apenas USAGE.
- Helpers de autorização e as seis implementações privilegiadas ficam no schema privado; os endpoints públicos são wrappers SECURITY INVOKER.
- Advisor de segurança não aponta mais funções SECURITY DEFINER expostas; o único aviso atual é proteção contra senhas vazadas desativada no plano Free.
- Teste transacional com rollback confirmou isolamento entre empresas, leitura de viewer, bloqueio de leitura comercial para employee e bloqueio de RPCs quando os módulos necessários estão desligados.
- Funcionário tem acesso a Jornada e Ponto próprios e Operação do ramo quando habilitada; não lê clientes, fornecedores, produtos, vendas, compras, financeiro ou documentos empresariais.
- Bucket company-documents é privado; limite configurado em 10 MB; políticas separam leitura e escrita por papel e módulo.
- Scanner atualizado para formatos suportados pelo navegador e desligamento da câmera ao ocultar/encerrar a página.
- Service worker mantém somente o shell estático offline; não há leitura ou gravação offline de dados empresariais.

## Pendências que impedem liberar clientes pagantes

1. **Histórico de migrations:** as 36 versões remotas agora têm arquivos canônicos ativos correspondentes. A pasta ativa tem 40 SQLs, incluindo quatro migrations-base históricas que não constam no histórico remoto. Os objetos correspondentes foram encontrados no banco, mas o CLI ainda precisa confirmar o plano. Não executar `supabase db push`, `db reset --linked` ou `migration repair` antes do `supabase db push --dry-run` e da revisão das quatro migrations extras. 
2. **Backup e restauração:** ainda não há prova técnica de backup lógico completo nem de restauração em projeto separado. A organização está no plano Free; não há backups gerenciados para download nem branching. O CLI exige computador, Docker e psql. Storage objects e configurações Auth/Edge Functions precisam de cópia separada.
3. **Proteção de senhas vazadas:** permanece desativada porque o recurso não está incluído no plano Free. O Supabase informa disponibilidade no Pro ou superior.
4. **Homologação no aparelho:** instalação PWA, atualização de cache, modo avião, câmera/scanner, upload e download ainda precisam ser confirmados no Android real.
5. **Convite de funcionário:** função de servidor autenticada e protegida por papel foi revisada; nenhum convite real foi enviado. O fluxo completo deve ser testado com endereço de teste e autorização do proprietário.
6. **Validação operacional/fiscal:** validar documentos e relatórios com dados de teste e confirmar limites e obrigações fiscais antes de anunciar esses recursos.

## Segurança antes de convidar clientes

- Confirmar Site URL e Redirect URLs do Supabase Auth com o domínio publicado correto.
- Exigir confirmação de e-mail e habilitar MFA para perfis administrativos quando possível.
- Manter RLS habilitado em todas as tabelas que contêm dados empresariais.
- Confirmar que o bucket de documentos é privado e que URLs de visualização são temporárias.
- Nunca colocar service_role, sb_secret_, certificados digitais ou credenciais de provedor no navegador ou no Git.
- Manter backups criptografados fora do repositório público e testar restauração em projeto separado.
- Não convidar clientes pagantes antes de concluir as pendências acima.

## Acesso em dispositivos

- Android: abrir o endereço HTTPS publicado no Chrome e instalar/adicionar à tela inicial.
- Computador: abrir em Chrome/Edge e usar o ícone de instalação ou o menu do navegador.
- O modo offline atual mantém somente a estrutura estática de abertura; não permite operações ou leitura de dados empresariais.
- O scanner exige câmera permitida pelo navegador e suporte a BarcodeDetector; digitação ou leitor USB/Bluetooth permanece como alternativa.

## Critério de aceite

A publicação do site e a validação estática não equivalem à homologação. O lançamento comercial exige backup e restauração comprovados, isolamento multiempresa, convite seguro, testes autenticados por papel, PWA/câmera/documentos homologados no aparelho e revisão fiscal/contábil dos recursos anunciados.


## Auditoria SQL complementar — 25/11/2026

Consulta somente de leitura ao PostgreSQL confirmou:
- 33/33 tabelas públicas com RLS habilitado; 0/33 com FORCE RLS.
- 126 políticas RLS públicas; nenhuma política encontrada com papel `anon`/PUBLIC ou condição universal `true`.
- Nenhum privilégio direto de tabela para `anon` em SELECT/INSERT/UPDATE/DELETE nas tabelas públicas.
- 12 funções `SECURITY DEFINER` em `public`: todas com `search_path = ''`, sem EXECUTE para `anon` e sem EXECUTE para `authenticated` (funções internas/trigger-only).
- 9 funções `SECURITY DEFINER` em `private`: todas com `search_path = ''`; EXECUTE para `authenticated`, sem EXECUTE para `anon`.
- Schema `private`: USAGE negado a `anon` e permitido a `authenticated`. A permissão SQL não confirma se o schema está ou não exposto pelo PostgREST/Data API; essa configuração precisa ser conferida no painel Supabase em API/Exposed schemas antes de convidar clientes.
- Nenhuma função `SECURITY DEFINER` do schema público ou privado é executável por `anon`.

O Advisor de segurança ainda mostra um aviso: proteção contra senhas vazadas desativada. O Advisor de performance mostra 45 índices sem uso observado; nenhum foi removido, pois o projeto está em desenvolvimento e alguns índices atendem integridade/consultas futuras.

**Limite:** FORCE RLS não foi ativado em lote. A configuração atual mantém RLS em todas as tabelas; aplicar FORCE indiscriminadamente pode alterar comportamento de funções proprietárias e rotinas. Qualquer ajuste deve ser avaliado por tabela e testado com contas reais.

## Quatro migrations extras: pendência já identificada

A pasta ativa contém quatro versões locais sem registro remoto: 202611070001, 202611080001, 202611080002 e 202611080003. O CLI deve listá-las como pendentes e o dry-run deve propor sua aplicação. Não executar o push.

A leitura do banco encontrou os principais objetos dessas migrations já presentes, mas 202611080001_erp_modules.sql contém um delimitador inválido (AS $ / $;) em record_stock_movement e inclui definições antigas de funções e privilégios. Reaplicá-la pode falhar ou reverter endurecimentos posteriores. Os quatro arquivos também dependem de objetos-base que não são criados por eles, como companies e helpers de autorização. Isso impede considerar a pasta atual um instalador limpo para projeto vazio.

A solução exige backup/restauração comprovados e decisão técnica entre baseline, arquivamento e reconciliação do histórico. Não fazer migration repair nem editar/aplicar esses arquivos sem revisão.
