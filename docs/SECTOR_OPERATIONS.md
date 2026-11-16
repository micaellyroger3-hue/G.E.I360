# Operação específica por ramo — G.E.I360

A empresa define o ramo em **Minha empresa** e acessa **Operação do ramo**. Os formulários mudam conforme o perfil:

| Ramo | Registros disponíveis |
|---|---|
| Alimentação preparada (restaurantes, lanchonetes, padarias, pizzarias e cafeterias) | Desperdício, produção e ficha de preparo (registros manuais) |
| Mercado e alimentos (mercadinhos, supermercados, mercearias, açougues e hortifrutis) | Validade, perdas/avarias e necessidade de reposição (registros manuais) |
| Loja / comércio | Campanhas/promos e tarefas comerciais |
| Prestação de serviços | Ordens de serviço |
| Distribuidora / atacado | Expedição e entrega |
| E-commerce | Separação e expedição de pedidos |
| Construção / obras | Diário de obra e etapas |

## Persistência e isolamento
O núcleo geral do G.E.I360 (cadastros, estoque, vendas, compras, clientes, fornecedores, financeiro e documentos) pode ser usado por diferentes atividades. Quando o ramo não estiver na lista, selecione **Outro ramo** para usar os módulos gerais e os registros operacionais genéricos.

Os registros setoriais são manuais e não significam automação completa. Os módulos recomendados só abrem telas existentes; itens sem tela correspondente permanecem identificados como planejados.

Os registros são armazenados em `public.gei_records`, com:
- `company_id` da empresa selecionada;
- `module_code = 'sector_ops'`;
- `record_type` para identificar o formulário;
- `payload` JSONB para os campos específicos;
- `created_by` preenchido com o usuário autenticado.

A tabela tem RLS. A leitura exige associação ativa à empresa; a inserção também exige associação ativa. O banco foi testado em transação com rollback: proprietário conseguiu inserir e usuário sem associação recebeu zero linhas na consulta.

## Limites atuais
Estes são controles operacionais manuais iniciais, não módulos de automação completa:
- Desperdício não baixa automaticamente estoque.
- Ficha de preparo não calcula custo por ingrediente nem margem real.
- Validade é um registro manual, não alerta automático.
- Ordens de serviço não geram cobrança automática.
- Entrega e expedição não integram transportadoras nem marketplaces.
- Selecionar iFood no perfil não importa pedidos nem sincroniza catálogo.

Integrações externas exigem credenciais oficiais, backend seguro, homologação e testes específicos. Nunca colocar tokens no navegador.
