# Matriz de acesso por perfil — G.E.I360

| Perfil | Acesso previsto |
|---|---|
| Proprietário | Todos os módulos habilitados; gestão da empresa, equipe, permissões, RH, financeiro e documentos |
| Administrador | Operação e administração da empresa; RH e remuneração conforme políticas; pode gerenciar módulos |
| Gerente | Operação, estoque, vendas, compras, financeiro, documentos, setor e jornada; sem remuneração, configuração de RH ou fechamento restrito |
| Visualizador | Leitura dos dados operacionais, comerciais, financeiros e documentos; sem escrita e sem RH |
| Funcionário | Jornada e ponto próprios e operação do ramo quando habilitada; não acessa equipe completa, remuneração, clientes, fornecedores, vendas, compras, financeiro ou documentos da empresa |

## Barreiras técnicas
- A navegação oculta áreas que o perfil não deve usar, mas não é considerada uma barreira de segurança.
- O RLS do banco restringe leituras e escritas por empresa e papel.
- Um helper privado verifica se o módulo está disponível e habilitado para aquela empresa; políticas RLS restritivas aplicam esse controle também a chamadas REST diretas.
- Desativar um módulo não apaga registros. O acesso volta quando o módulo é reativado.
- Módulos essenciais permanecem habilitados; módulos sem configuração específica continuam habilitados por padrão quando disponíveis.
- Documentos ficam em bucket privado; funcionário não lê documentos empresariais.
- O funcionário pode continuar usando Operação do ramo se Gestão de Serviços ou Produção e Indústria estiver habilitado, porque essa área representa tarefas operacionais, não acesso financeiro.
