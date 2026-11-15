# G.E.I360
Plataforma de Gestão Empresarial.

## Aplicativo
O G.E.I360 é uma aplicação web instalável (PWA) para Android e desktop. O cache offline mantém somente a estrutura estática de abertura; autenticação e dados empresariais exigem conexão com a internet.

## Módulos presentes no código integrado
- Cadastro, login, renovação de sessão, recuperação de senha e logout.
- Cadastro e seleção de empresas, com vínculo de proprietário.
- Cadastro, edição e exclusão de funcionários (fichas; não cria login para o funcionário).
- Perfil empresarial por ramo e canais comerciais.
- Clientes, fornecedores, categorias e produtos.
- SKU, código de barras, câmera em navegadores compatíveis e leitores USB/Bluetooth.
- Estoque com entrada, saída e ajuste.
- Compras e vendas com carrinho de vários produtos.
- Contas a pagar/receber e lançamentos financeiros automáticos para compras/vendas.
- Documentos e anexos privados no Supabase Storage.
- Indicadores e exportação CSV.

## Estado atual do Supabase
Projeto: `mxikqdarqgatqoecfprg` (ativo e saudável).

O banco já continha tabelas e dados antes desta revisão, mas o histórico de migrations estava vazio. Por isso, **não execute `supabase/INSTALL_GEI360_ALL.sql` neste projeto**: o antigo instalador consolidava migrations-base que não correspondem integralmente ao schema preexistente. O arquivo foi desativado como proteção contra execução acidental.

Foram aplicadas migrations direcionadas e registradas no Supabase:
- `company_business_profiles`
- `integrity_hardening`
- `product_categories`
- `product_barcode_integrity`
- `employee_integrity`
- `foreign_key_indexes_rls_tuning`
- `deduplicate_category_policies`
- `api_privilege_hardening`

Também foi feita a verificação de privilégios. Resultado confirmado: nenhuma concessão de tabela a `anon` nas tabelas públicas auditadas e nenhum privilégio estrutural `TRUNCATE/REFERENCES/TRIGGER/MAINTAIN` para `authenticated` nessas tabelas. Todas as 20 tabelas públicas verificadas estão com RLS habilitado. O bucket `company-documents` está privado.

### Testes executados no banco
- Helpers de associação e cargo reconheceram o proprietário ativo.
- Teste RLS simulado com associação inativa: a empresa ficou invisível e a escrita cruzada foi negada; ainda falta homologação com duas contas reais.
- Usuário autenticado não conseguiu inserir/alterar diretamente o saldo de estoque.
- Usuário autenticado não conseguiu gravar diretamente os campos de origem do financeiro.
- Fluxo de recebimento: compra, item, entrada no estoque e despesa financeira automática — aprovado.
- Fluxo de venda: venda, item, baixa no estoque e receita financeira automática — aprovado.
- Os registros usados nesses testes foram revertidos com `ROLLBACK`; nenhum produto, compra ou venda de teste ficou salvo.
- Não há chaves de barras duplicadas nos produtos existentes; não há FKs públicas sem índice de cobertura.

### Pendências reais antes de produção
- Fazer teste de isolamento com duas contas autenticadas e duas empresas diferentes; só assim se prova que uma empresa não lê nem altera dados da outra.
- Rever a tabela legada `empresas`: RLS está ativo e ela não possui policies; não foi apagada.
- O Supabase Advisor ainda sinaliza funções `SECURITY DEFINER` acessíveis a `authenticated`. São RPCs e helpers operacionais previstos no app, com validação de usuário/empresa/cargo; manter revisão periódica de seus corpos e permissões.
- Ativar a proteção de senha vazada em Authentication, conforme a configuração do Supabase.
- Os índices recém-criados aparecem como “não utilizados” porque o banco ainda tem pouco tráfego; não significa falha.
- O histórico de migrations do banco contém as oito migrations direcionadas acima, não a sequência-base completa do repositório. Não usar `supabase db push` nem o antigo instalador até reconciliar formalmente esse histórico com os arquivos locais.
- A PR #5 ainda precisa de validação do GitHub Actions e revisão antes de merge para `main`. Não anunciar publicação enquanto não houver merge e deploy bem-sucedido.

## Limitações funcionais
- NF-e/NFC-e: organiza documentos e anexos; não emite nem transmite documentos à SEFAZ.
- iFood: o canal pode ser selecionado no perfil, mas não há sincronização de pedidos ou catálogo.
- IA generativa: não existe assistente generativo conectado.
- Funcionários: cadastrar uma ficha não cria conta de acesso.
- Offline: somente a estrutura estática de abertura fica disponível sem internet.

## Publicação
O workflow de publicação está em `.github/workflows/static.yml` e publica a branch `main` no GitHub Pages. A versão integrada continua na PR #5; aguarde Actions verde, revisão e merge antes de considerar a publicação concluída.

## Segurança de chaves
O front-end pode conter somente URL do projeto e chave publicável. Nunca exponha `service_role` ou chave secreta no navegador.
