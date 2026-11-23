# G.E.I360 — checklist de preparação para clientes

## Estado verificado em 23/11/2026

- PRs de segurança e navegação #31, #36, #37 e #38 integrados à branch main.
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

1. **Histórico de migrations:** 36 versões remotas e 39 arquivos locais não estão sincronizados; existem 3 migrations remotas sem arquivo local, 5 arquivos locais sem nome correspondente no histórico e prefixos de versão diferentes/duplicados. Não executar `supabase db push` nem `db reset --linked` antes da reconciliação. 
2. **Backup e restauração:** ainda não foi executado um backup lógico completo nem uma restauração em projeto separado. A organização está no plano Free; não há backups gerenciados para download nem branching. O CLI exige computador, Docker e psql. Storage objects e configurações Auth/Edge Functions precisam de cópia separada.
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
