# G.E.I360 — preparação para integração fiscal brasileira

## Situação atual
O módulo atual organiza notas recebidas, comprovantes e anexos. Ele ainda não emite NF-e ou NFC-e e não transmite documentos à SEFAZ. Um cadastro ou PDF anexado não equivale a uma nota fiscal autorizada.

## Estratégia recomendada
Integrar um provedor fiscal brasileiro por meio de uma camada de servidor do G.E.I360. O navegador nunca deve receber certificado digital, senha de certificado, token privado do provedor ou chave de serviço do Supabase.

Fluxo proposto:
1. O usuário autorizado prepara uma venda e solicita a emissão.
2. O servidor valida empresa, permissões, cadastro fiscal, produtos e totais.
3. O servidor envia a solicitação ao provedor fiscal no ambiente de homologação.
4. O servidor salva protocolo, status, chave de acesso, XML e DANFE quando retornados.
5. O G.E.I360 exibe o resultado e permite baixar/consultar arquivos autorizados.
6. Cancelamento, inutilização e correção seguem as regras fiscais e ficam registrados em auditoria.

## Dados que precisam ser configurados por empresa
- CNPJ, razão social, nome fantasia e endereço fiscal.
- Inscrição estadual e municipal, quando aplicáveis.
- Regime tributário e enquadramento fiscal.
- UF, município e ambiente (homologação antes de produção).
- Certificado digital aceito pelo provedor (A1/A3 conforme integração) e credenciais guardadas somente no servidor.
- Para cada produto: NCM, CEST quando aplicável, origem, unidade, CFOP conforme operação, CST/CSOSN e demais regras tributárias exigidas.
- Para cada operação: destinatário, endereço, finalidade, natureza da operação, frete, descontos e tributação.

Os campos e regras exatos variam conforme regime, UF, operação, modelo de documento e legislação vigente. Um contador deve validar a parametrização.

## Contrato mínimo da integração no servidor
A camada de servidor deverá expor operações autenticadas para:
- validar a configuração fiscal da empresa;
- emitir em homologação;
- consultar situação/protocolo;
- recuperar XML e DANFE;
- cancelar quando permitido;
- registrar eventos e trilha de auditoria.

Cada operação precisa conferir a associação do usuário à empresa e a permissão específica. Idempotência é obrigatória para evitar emissão duplicada em repetição de rede. Segredos e certificados ficam em secrets do servidor, nunca em index.html, modules.js, Git ou armazenamento local do navegador.

## Critérios para liberar produção
- Provedor escolhido e contrato/credenciais obtidos.
- Homologação aprovada para cada modelo e operação que será oferecida.
- XML e DANFE conferidos por responsável fiscal.
- Testes de duplicidade, falha de rede, rejeição, cancelamento e consulta.
- Logs sem expor certificado, senha ou tokens.
- Aprovação do contador e credenciamento/autorizações exigidos pela UF.

## Próximo bloqueio externo
Não é seguro escolher um provedor, inventar credenciais ou implementar transmissão real sem a decisão comercial e fiscal da empresa. A estrutura deve permanecer em homologação até esses itens serem fornecidos e validados.
