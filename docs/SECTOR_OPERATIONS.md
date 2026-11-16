# Operação específica por ramo — G.E.I360

A empresa define o ramo em **Minha empresa** e acessa **Operação do ramo**. Os formulários mudam conforme o perfil:

| Ramo | Registros disponíveis |
|---|---|
| Restaurante / lanchonete | Desperdício, produção e ficha de preparo |
| Mercado / mercearia | Validade, perdas/avarias e necessidade de reposição |
| Loja / comércio | Campanhas/promos e tarefas comerciais |
| Prestação de serviços | Ordens de serviço |
| Distribuidora / atacado | Expedição e entrega |
| E-commerce | Separação e expedição de pedidos |
| Construção / obras | Diário de obra e etapas |

## Persistência e isolamento
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
