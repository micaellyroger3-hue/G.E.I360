# G.E.I.360

Plataforma de gestão empresarial multiempresa, com módulos gerais e operações específicas por ramo.

## Acesso

- **Aplicativo:** https://micaellyroger3-hue.github.io/G.E.I360/
- **Apresentação:** https://micaellyroger3-hue.github.io/G.E.I360/apresentacao-mercadinhos.html
- **Formato:** PWA instalável em Android e desktop.
- **Publicação:** GitHub Pages. A validação automatizada e o deploy do commit atual foram concluídos com sucesso em 23/11/2026.
- **Offline:** somente a estrutura estática de abertura fica disponível; login e dados empresariais exigem internet.

## Módulos disponíveis no código

- Cadastro, login, renovação de sessão, recuperação de senha e logout.
- Cadastro e seleção de empresas, perfil por ramo e canais comerciais.
- Minha empresa e configuração de módulos disponíveis.
- Funcionários e RH: fichas, remuneração mensal ou por hora, convites, escalas e ponto gerencial.
- Clientes, fornecedores, categorias, produtos, SKU e código de barras.
- Estoque, entradas, saídas e ajustes.
- Compras e vendas com carrinho e integração com movimentações e lançamentos financeiros.
- Contas a pagar e receber, documentos privados e anexos.
- Painel de indicadores, relatórios e exportação CSV.
- Operação por ramo: alimentação preparada; mercado e alimentos; comércio; serviços; distribuidora/e-commerce; construção.

Os módulos disponíveis para cada empresa são organizados pelo catálogo `gei_module_catalog` e pelas atribuições `company_modules`. A interface pode ocultar áreas, mas a autorização efetiva também é aplicada no banco por RLS e controles de papel/módulo.

## Limites funcionais importantes

Os registros específicos por ramo são lançamentos operacionais manuais. Eles não fazem baixa automática no estoque, não calculam custo real de receitas e não substituem módulos completos de produção, logística ou fiscal.

Ainda não existem:
- Integração oficial com iFood ou sincronização automática de marketplaces.
- Emissão ou transmissão de NF-e/NFC-e à SEFAZ.
- Assistente de IA generativa conectado.
- PDV completo, TEF, processamento de Pix/cartão ou integração bancária automática.
- Folha oficial, eSocial, FGTS Digital ou ponto eletrônico homologado como REP-P/REP-A/REP-C.

O RH e a apuração de jornada são ferramentas gerenciais e estimativas. Parâmetros e resultados devem ser conferidos por profissional de DP/contabilidade; não declarar conformidade oficial ou certificação.

## Supabase e segurança

- Projeto: `mxikqdarqgatqoecfprg`.
- Estado verificado em 23/11/2026: `ACTIVE_HEALTHY`, PostgreSQL 17.
- 33/33 tabelas públicas com RLS habilitado.
- Controles restritivos de papel e módulo aplicados a 26 tabelas; desativar um módulo bloqueia o acesso correspondente sem apagar registros.
- Grants legados de sequências públicas removidos para `anon`; `authenticated` mantém somente o uso necessário.
- Helpers de autorização e implementações privilegiadas movidos para schema privado; endpoints públicos são wrappers `SECURITY INVOKER`.
- Advisor de segurança: o único aviso atual é a proteção contra senhas vazadas desativada no Auth. No plano Free atual, esse recurso exige upgrade.
- Bucket `company-documents` privado, com políticas por papel e módulo e limite configurado de 10 MB.
- Edge Function `invite-company-member` ativa, versão 5, com JWT obrigatório. O convite real e o aceite ainda precisam ser homologados com um e-mail de teste sob controle do proprietário.

Esses controles reduzem riscos, mas não representam garantia absoluta de segurança nem substituem backup, monitoramento e homologação.

## Estado da revisão de prontidão — 25/11/2026

- CI da PR #48: aprovado em duas execuções; PR ainda em rascunho e não integrada à `main`.
- Histórico remoto Supabase: 36 versões, todas com arquivos canônicos ativos correspondentes no repositório.
- Pasta ativa: 40 SQLs; quatro migrations-base históricas adicionais não registradas no histórico remoto aguardam `supabase migration list` e `supabase db push --dry-run` no computador. Não executar push/repair/reset antes dessa conferência.
- Banco: 33/33 tabelas públicas com RLS; FORCE RLS desativado nas 33; nenhuma concessão direta de SELECT/INSERT/UPDATE/DELETE a `anon` nas tabelas examinadas.
- Advisor de segurança: proteção contra senhas vazadas desativada. A exposição do schema `private` na Data API ainda precisa ser confirmada no painel.
- Nenhuma alteração SQL de produção foi executada nesta revisão.

## Pendências antes de liberar clientes pagantes

1. **Backup e restauração:** ainda não foi concluído um backup lógico completo nem uma restauração de ensaio em projeto separado. O plano Free não oferece backups gerenciados para download; banco, objetos do Storage e configurações de Auth/Edge Functions precisam de cópias próprias.
2. **Histórico de migrations:** as 36 versões remotas agora têm arquivos canônicos ativos correspondentes. Há quatro migrations-base adicionais na pasta ativa, ausentes do histórico remoto; o dry-run do CLI precisa confirmar que não serão reaplicadas. Não executar `supabase db push`, `supabase db reset --linked` ou reparo do histórico antes dessa conferência.
3. **Homologação em dispositivos:** confirmar instalação/atualização PWA, modo avião, câmera/scanner e upload/download no Android real e em desktop.
4. **Homologação multiusuário:** testar duas contas reais em empresas distintas e a matriz completa owner/admin/manager/employee/viewer, inclusive documentos e módulos desativados.
5. **Convite de funcionário:** testar envio, recebimento, aceite e definição de senha com e-mail de teste; confirmar SMTP e URLs de redirecionamento.
6. **Revisão fiscal e contábil:** conferir documentos, relatórios, parâmetros e limites antes de anunciar recursos fiscais ou de RH.

**Não cadastrar clientes pagantes antes de concluir essas etapas.** Consulte `docs/CLIENT_READINESS.md`, `docs/MIGRATION_HISTORY_RECONCILIATION.md` e `docs/BACKUP_RESTORE_RUNBOOK.md` para o roteiro detalhado.

## Proteção de chaves e dados

O navegador pode conter somente a URL do projeto e a chave publicável. Nunca colocar `service_role`, `sb_secret_`, certificados digitais, senhas ou credenciais de terceiros no frontend ou no repositório.

O instalador consolidado legado `supabase/INSTALL_GEI360_ALL.sql` está desativado. Não executá-lo. Não alterar o histórico remoto de migrations nem fazer operações de reset/push até concluir a reconciliação documentada.
