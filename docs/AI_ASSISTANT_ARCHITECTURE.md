# G.E.I360 — inteligência artificial e conhecimento empresarial

## Visão do produto
O G.E.I360 deve evoluir de um ERP com indicadores para um assistente de gestão que entende perguntas em português, explica os números da empresa e ajuda o usuário a executar tarefas autorizadas.

## O que já existe
O painel possui uma primeira camada de inteligência de gestão baseada em regras determinísticas: alertas de estoque mínimo, contas vencidas, valores a receber/pagar, mês sem vendas confirmadas e produtos inativos. Ela usa registros reais já carregados para a empresa selecionada e explica a origem das observações. Não é ainda um modelo generativo e não deve ser anunciada como chat de IA.

## Capacidades planejadas para o assistente
- Perguntas: “Quanto vendemos este mês?”, “Quais contas vencem esta semana?”, “Quais produtos precisam de reposição?”
- Explicações: mostrar como cada indicador foi calculado e quais registros o compõem.
- Recomendações: sugerir revisão de estoque, cobrança ou planejamento de pagamentos, sem prometer resultados.
- Ajuda de uso: explicar como cadastrar produto, lançar compra, registrar venda ou gerar relatório.
- Ações assistidas: preparar uma operação e pedir confirmação explícita antes de gravar, pagar, excluir ou solicitar emissão fiscal.

## Arquitetura obrigatória
1. Interface do assistente dentro do G.E.I360.
2. Endpoint server-side (Supabase Edge Function ou serviço equivalente) autenticado com JWT do usuário.
3. A função valida usuário, empresa ativa, papel e permissão; nunca confia em company_id enviado pelo navegador sem validar associação.
4. Consultas de contexto executadas no servidor sob isolamento por empresa/RLS. Só o mínimo necessário é enviado ao modelo.
5. Modelo de linguagem chamado exclusivamente no servidor por segredo guardado em secrets. Nenhuma chave de IA no navegador ou repositório.
6. Resposta estruturada com explicação, dados usados, período, ressalvas e fonte/módulo.
7. Ferramentas de escrita exigem confirmação explícita do usuário e revalidam permissão/estado no servidor.

## Segurança, privacidade e confiabilidade
- Nunca compartilhar contexto entre empresas ou entre usuários sem autorização.
- Não enviar certificados digitais, senhas, tokens, dados de cartão ou documentos pessoais desnecessários ao modelo.
- Não usar IA para inventar saldo, venda, estoque ou situação fiscal. Se a consulta falhar ou os dados forem insuficientes, dizer isso.
- Para valores, datas e totais, consultar o banco e calcular no servidor; o modelo apenas explica o resultado.
- Toda ação deve ser auditada: usuário, empresa, ferramenta, parâmetros permitidos, confirmação e resultado.
- Limitar tamanho de contexto, frequência e custo por empresa/usuário.
- Informar quando uma resposta é gerada por IA e permitir revisão humana.
- A IA não substitui contador, advogado, profissional fiscal ou decisão de crédito.

## Etapas para ativação real
1. Escolher o provedor/modelo e aceitar seus termos de tratamento de dados.
2. Criar Supabase Edge Function com autenticação, autorização e consultas estritamente limitadas.
3. Guardar a chave do provedor em Supabase Edge Function Secrets; nunca no cliente.
4. Implementar primeiro perguntas somente leitura e respostas ancoradas nos dados consultados.
5. Testar isolamento com usuários de duas empresas, tentativas de prompt injection, perguntas fora do escopo, dados ausentes, limites e falhas do provedor.
6. Só depois adicionar ações com confirmação explícita e trilha de auditoria.

## O que não será ativado sem configuração
Não há chave de provedor de IA nem função de servidor de IA configurada no projeto neste momento. Por isso, não se deve exibir um chat fingindo que responde com um modelo real. A primeira camada de insights locais é útil hoje; a conversa generativa entra quando o endpoint seguro e o provedor estiverem configurados e testados.
