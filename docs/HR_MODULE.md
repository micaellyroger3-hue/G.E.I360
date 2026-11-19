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


## Jornadas, escalas e ponto

- Configuração por funcionário: 12x36 com data-base de ciclo e indicação de trabalho/folga, trabalho por hora, horário fixo, 6x1, 5x2, personalizada e variável.
- Remuneração pode ser mensal ou por hora; a estimativa mensal por hora usa valor/hora × horas semanais × 52 ÷ 12. É uma aproximação gerencial e não substitui o cálculo da folha ou o fechamento de horas efetivamente trabalhadas.
- Marcações de entrada, início/fim de intervalo e saída são registradas pelo relógio do servidor (`clock_timestamp()`), com horário `timestamptz` e origem (funcionário ou gestor).
- Marcações originais não podem ser alteradas ou excluídas pelo cliente. Correções devem ter justificativa e aprovação, preservando a trilha original.
- A conta do funcionário pode reivindicar a ficha quando o e-mail autenticado coincide com o e-mail cadastrado e existe vínculo ativo com papel employee.
- O recurso é gerencial e ainda não está homologado como REP-P/REP-A/REP-C. Não emitir espelho legal de ponto ou prometer conformidade antes de revisão jurídica/técnica e validação com o DP.


## Apuração mensal, adicionais e fechamento

A tela **Apuração de jornada** (menu RH) acrescenta:

- Parâmetros configuráveis por empresa: limite semanal, limite diário opcional, adicional de horas extras, regra de domingo/feriado, adicional e faixa noturna, hora noturna reduzida, tolerância e configuração de banco de horas.
- Apuração por marcações originais, separando jornada diária, extras diárias e complemento semanal sem somar duas vezes a mesma hora.
- Estimativa de adicional noturno, considerando faixa configurada e duração reduzida da hora noturna quando habilitada.
- Calendário de feriados nacional, estadual, municipal e da empresa. O cadastro é por empresa; feriados municipais/estaduais precisam ser informados e conferidos pelo responsável.
- Conferência de escala x marcações, com alertas de ausência, entrada/saída faltante e intervalo sem marcação. O sistema não aplica desconto automático.
- Ocorrências justificadas/não justificadas, com observação e responsável pela revisão.
- Livro de banco de horas append-only (crédito/débito/expiração/pagamento/ajuste), validade do crédito e saldo por funcionário.
- Exportação CSV gerencial e fechamento mensal por funcionário, com resumo persistido, bloqueio de novos pontos/tratamentos e possibilidade de reabertura mediante justificativa.

### Critérios e cautelas de cálculo

- O adicional mínimo geral de hora extra é configurado inicialmente em 50%; o sistema permite adequação a percentuais maiores previstos em instrumento coletivo.
- O adicional noturno urbano parte de 20% e hora reduzida de 52min30s, mas o período e as condições podem variar conforme atividade, categoria e instrumento coletivo.
- O multiplicador de 100% para feriado/domingo é apenas uma configuração inicial de referência. O enquadramento de domingo depende da escala, repouso semanal compensatório, legislação específica e convenção coletiva. O sistema apresenta estimativa e exige conferência.
- O cálculo de salário-hora mensal usa divisor estimado a partir da jornada semanal (ex.: 44h → 220); o divisor correto deve ser confirmado para cada categoria/regime.
- Banco de horas só deve ser ativado depois de cadastrar o tipo de acordo e conferir sua validade, limites e compensações. Lançamentos manuais exigem justificativa; o sistema não presume acordo válido.
- Alertas de ausência são gerados ao abrir a tela e podem ser gravados como ocorrências pelo responsável. Não existe desconto ou punição automática.

### Limite regulatório do ponto eletrônico

O módulo é um **programa de tratamento e gestão de jornada**, não um REP-P certificado nem um sistema de folha. A marcação via servidor, trilha de auditoria e proteção de registros são controles importantes, mas não bastam para declarar conformidade integral com a Portaria MTP 671/2021. Um REP-P exige, entre outros pontos, sincronismo com a Hora Legal Brasileira, armazenamento de registros com integridade e redundância, NSR, comprovantes e assinaturas qualificadas ICP-Brasil; o desenvolvedor também deve fornecer o Atestado Técnico e Termo de Responsabilidade quando aplicável. Antes de usar como controle oficial, é necessária validação técnica, jurídica e documental com profissional de DP/contador e certificação/assinaturas exigidas.
