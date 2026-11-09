# G.E.I360 — checklist de preparação para clientes

## Acesso em dispositivos
- Android: abrir o endereço publicado em Chrome/Edge, menu do navegador e escolher Instalar aplicativo ou Adicionar à tela inicial, se disponível.
- Computador: abrir em Chrome/Edge e usar o ícone de instalação na barra de endereço ou o menu Instalar página como app.
- Tablet: mesmo procedimento do Android ou do navegador desktop, conforme o sistema.
- O acesso exige internet para autenticar e trabalhar com dados da empresa.
- O modo offline atual mantém somente a estrutura estática de abertura; não permite operações ou leitura de dados empresariais.

## Segurança antes de convidar clientes
- Confirmar Site URL e Redirect URLs do Supabase Auth com o domínio publicado correto.
- Exigir confirmação de e-mail e habilitar MFA para perfis administrativos quando possível.
- Testar com dois usuários de teste em empresas diferentes: nenhum pode ler, alterar, exportar ou anexar dados da outra empresa.
- Testar cada papel (owner, admin, manager e demais papéis) e negar ações não autorizadas no banco, não apenas esconder botões.
- Manter RLS habilitado em todas as tabelas que contêm dados empresariais.
- Confirmar que bucket de documentos é privado e que URLs de visualização são temporárias.
- Nunca colocar service_role, sb_secret_, certificados digitais ou credenciais de provedor no navegador ou no Git.
- Definir política de backup, retenção, restauração e resposta a incidentes.

## Operação e suporte
- Criar fluxo seguro de convite de funcionários com função de servidor e provedor de e-mail; cadastrar funcionário não cria automaticamente uma conta de login.
- Criar trilha de auditoria para alterações sensíveis, exclusões, movimentações e ações fiscais.
- Validar importação/exportação e relatórios com dados reais de teste.
- Documentar suporte, disponibilidade, limites, tratamento de dados e encerramento de contas.
- Não cadastrar clientes pagantes antes dos testes integrados e de isolamento multiempresa.

## Critério de aceite
A publicação do site e a validação estática são apenas uma parte. O lançamento comercial exige testes autenticados no Supabase, isolamento entre empresas, recuperação de backup, fluxo de convite e validação fiscal/contábil dos recursos anunciados.
