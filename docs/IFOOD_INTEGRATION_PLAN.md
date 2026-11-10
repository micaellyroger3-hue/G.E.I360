# Integração oficial com iFood — plano técnico

## O que já existe no G.E.I360
- O cadastro empresarial permite marcar iFood como canal utilizado.
- O perfil mostra que a integração está pendente.
- O sistema não pede credenciais do iFood no navegador e não simula pedidos.

## Elegibilidade e aprovação
A documentação pública do iFood Developer informa que o fluxo começa no Portal do Desenvolvedor, com ambiente e loja de teste. Depois do desenvolvimento e dos testes, é necessário criar o aplicativo de produção e solicitar homologação. A página informa como requisitos para uso das APIs: CNPJ válido (CPF não aceito), CNAE relacionado a tecnologia e aplicativo completo e funcional para homologação. A aprovação libera a ativação nas lojas de produção.

Fontes oficiais:
- Portal: https://developer.ifood.com.br/pt-BR
- Primeiros passos: https://developer.ifood.com.br/pt-BR/docs/getting-started/
- FAQ e homologação: https://developer.ifood.com.br/pt-BR/support/

## Etapas técnicas obrigatórias
1. Confirmar a modalidade correta: Restaurante (Food) ou Mercado (Grocery). As jornadas e módulos disponíveis diferem.
2. Criar conta de desenvolvedor e obter credenciais de teste no portal oficial.
3. Definir os escopos/módulos aprovados para a integração pretendida.
4. Implementar OAuth/token exchange somente no servidor; nunca expor client secret, access token ou refresh token no JavaScript do navegador.
5. Implementar recebimento de eventos/webhooks com validação, idempotência, retries e registro de auditoria.
6. Mapear merchant/loja para a empresa do G.E.I360 com autorização explícita de usuário proprietário.
7. Para pedidos: importar, atualizar estados, tratar cancelamentos e evitar duplicidade.
8. Para catálogo/estoque: mapear SKU/EAN, unidades, disponibilidade, preço e sincronização com conflitos controlados.
9. Para financeiro: reconciliar repasses, taxas, ajustes e pedidos com origem identificada, sem duplicar lançamentos.
10. Criar testes automatizados com loja de teste, logs sem segredos e tratamento de indisponibilidade.
11. Submeter o app completo à homologação oficial e só então habilitar lojas reais.

## Bloqueios que não podem ser resolvidos apenas por código
- Aprovação e credenciais do portal do desenvolvedor.
- CNPJ e CNAE elegíveis conforme regras vigentes do iFood.
- Definição do tipo de integração (Restaurante ou Mercado) e dos módulos necessários.
- Autorização da loja/merchant pelo usuário gerencial da loja.
- Homologação oficial e acesso de produção.

**Estado atual:** perfil empresarial e seleção do canal estão preparados no código. Integração real de pedidos, catálogo, cancelamentos, webhooks e conciliação financeira ainda não foi implementada nem homologada.
