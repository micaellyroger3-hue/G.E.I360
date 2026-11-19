# G.E.I360 — RH e custo de pessoal

## Escopo implementado

- Cadastro de funcionário com cargo, departamento, admissão, situação, tipo de vínculo, remuneração mensal, jornada, escala e benefícios.
- Área separada para remuneração e custos, acessível somente a proprietário e administrador.
- Parâmetros por empresa: regime tributário, anexo do Simples, INSS patronal, FGTS, RAT/SAT, terceiros e provisões de 13º e férias.
- Cálculo gerencial mensal por pessoa e total da equipe.
- Controle administrativo de férias, ausências, afastamentos, atestados e outras ocorrências. Não registrar diagnóstico, CID ou detalhes clínicos nas observações.
- Exportação CSV de equipe e custos.
- Lançamento opcional do custo mensal estimado no Financeiro, com trava de unicidade por empresa e competência.

## Privacidade e segurança

Salários e benefícios não são adicionados à tabela pública de cadastro de funcionários. São armazenados em `employee_compensation`, com RLS e leitura restrita a `owner` e `admin`. Parâmetros tributários, eventos de RH e controle de lançamentos também têm políticas restritas. O vínculo entre funcionário e empresa é validado no banco.

## Regras de cálculo

- O salário mensal e os benefícios informados compõem a base do custo gerencial.
- Para CLT, são estimados FGTS, INSS patronal conforme configuração, RAT/SAT e terceiros conforme alíquotas informadas, além das provisões selecionadas de 13º e férias + 1/3.
- MEI selecionado usa 3% de contribuição patronal e 8% de FGTS como referência para o único empregado permitido; o sistema alerta se houver mais de um funcionário ativo no cadastro.
- Simples Nacional não presume contribuição patronal fora do DAS quando o anexo configurado não é o IV. No Anexo IV, a contribuição patronal é tratada separadamente, com taxa inicial sugerida de 20% que deve ser confirmada.
- Lucro Presumido/Real sugere contribuição patronal separada; RAT e terceiros permanecem em zero até serem informados.
- Vínculos diferentes de CLT não recebem encargos automáticos nesta versão; o custo apresentado é remuneração + benefícios e deve ser complementado.
- Funcionários afastados permanecem no cálculo enquanto o vínculo não estiver inativo.

## Limitações importantes

Este módulo é uma ferramenta de gestão e estimativa. Não gera folha oficial, holerite, recibo legal, férias/rescisão oficial, eventos ou guias do eSocial, FGTS Digital, DCTFWeb ou sistemas governamentais. Não calcula automaticamente convenção coletiva, piso regional, adicionais, horas extras, FAP, SST, terceiros específicos ou regras particulares de cada vínculo. As alíquotas e o enquadramento precisam ser confirmados por contador ou profissional de DP antes de decisões, recolhimentos ou pagamentos.

O lançamento no Financeiro cria uma despesa gerencial pendente, uma vez por competência; não marca pagamento automaticamente e não substitui o fechamento da folha.
