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
- Vínculos diferentes de CLT não recebem encargos automáticos nesta versão; o custo apresentado é remuneração + benefícios e deve ser complementado. A apuração de jornada calcula estimativas configuráveis de horas extras, adicional noturno, domingos/feriados e intervalos, mas não substitui folha nem validação de CCT.
- Funcionários afastados permanecem no cálculo enquanto o vínculo não estiver inativo.

## Limitações importantes

Este módulo é uma ferramenta de gestão e estimativa. Não gera folha oficial, holerite, recibo legal, férias/rescisão oficial, eventos ou guias do eSocial, FGTS Digital, DCTFWeb ou sistemas governamentais. Não interpreta automaticamente convenção coletiva, piso regional, FAP, SST, terceiros específicos, reflexos em DSR/13º/férias ou regras particulares de cada vínculo. As horas extras e adicionais mostrados na apuração são estimativas parametrizadas, não rubricas oficiais de folha. As alíquotas e o enquadramento precisam ser confirmados por contador ou profissional de DP antes de decisões, recolhimentos ou pagamentos.

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
- Estimativa de adicional noturno, considerando faixa configurada, prorrogação após as 5h quando houver continuidade e duração reduzida da hora noturna quando habilitada.
- Calendário de feriados nacional, estadual, municipal e da empresa. Há atalho para cadastrar feriados nacionais fixos; feriados estaduais/municipais e datas móveis locais precisam ser conferidos e cadastrados pelo responsável.
- Conferência de escala x marcações, com alertas de ausência, entrada/saída faltante e intervalo sem marcação. O sistema não aplica desconto automático.
- Ocorrências justificadas/não justificadas, com observação e responsável pela revisão.
- Livro de banco de horas append-only (crédito/débito/expiração/pagamento/ajuste), validade do crédito e saldo por funcionário; a expiração processa apenas o saldo remanescente de cada crédito e impede uso após o vencimento.
- Exportação CSV gerencial e fechamento mensal por funcionário, com resumo persistido de horas, extras, atrasos, saídas antecipadas e adicionais, bloqueio de novos pontos, ajustes, ocorrências e mudanças de escala na competência fechada, e possibilidade de reabertura mediante justificativa.

### Critérios e cautelas de cálculo

- O adicional mínimo geral de hora extra é configurado inicialmente em 50%; o sistema permite adequação a percentuais maiores previstos em instrumento coletivo.
- O adicional noturno urbano parte de 20% e hora reduzida de 52min30s, mas o período e as condições podem variar conforme atividade, categoria e instrumento coletivo.
- O multiplicador de 100% para feriado/domingo é apenas uma configuração inicial de referência. O enquadramento depende da escala e da folga compensatória: ao cadastrar uma folga extra na mesma semana, o sistema deixa de presumir pagamento em dobro naquele dia. A escala 12x36 recebe tratamento específico do art. 59-A da CLT para feriados e prorrogação noturna; diferenças previstas em ACT/CCT precisam de revisão manual.
- O divisor automático do salário-hora acompanha a jornada semanal efetiva: 44h → 220, 42h → 210 e 40h → 200. A transição constitucional passa a 42h em 16/12/2026 e 40h em 16/12/2027. O sistema limita a apuração semanal ao teto aplicável por data, sem reduzir o salário cadastrado. Pode-se registrar por funcionário um divisor menor e mais favorável previsto em ACT/CCT; não se deve usar divisor maior que o automático sem validação jurídica específica.
- Banco de horas só deve ser ativado depois de cadastrar o tipo de acordo e conferir sua validade, limites e compensações. A validade configurada é limitada a 6 meses no acordo individual escrito e 12 meses no acordo/convenção coletiva; o fator de conversão do crédito é configurável e começa em 1:1. No fechamento, horas extras podem ser creditadas automaticamente quando o banco e o instrumento estiverem habilitados. Créditos vencidos são lançados no livro por movimento de expiração. Lançamentos manuais exigem justificativa; o sistema não presume acordo válido.
- Alertas de ausência, entrada/saída, intervalo e interjornada são calculados ao abrir a tela e podem ser gravados como ocorrências pelo responsável. O intervalo intrajornada considera 60 minutos para jornadas acima de 6h (configurável, por exemplo, para 30 min quando permitido por ACT/CCT) e 15 minutos entre 4h e 6h; minutos suprimidos geram estimativa indenizatória somente após confirmação/revisão. O intervalo entre jornadas é conferido em 11h, ou 36h no 12x36. Não existe desconto ou punição automática.

### Transição constitucional de jornada — EC 141/2026

- Até 15/12/2026, o teto geral usado na apuração é 44h semanais; de 16/12/2026 a 15/12/2027, 42h; a partir de 16/12/2027, 40h. O salário cadastrado não é reduzido.
- A partir de 16/12/2026, a regra geral passa a prever dois repousos semanais remunerados. A tela calcula a média de repousos no mês e alerta para mais de seis dias consecutivos de trabalho. Folgas extras e trabalho em dia de folga podem ser lançados por funcionário para refletir ACT/CCT.
- Escalas 6x1 e 12x36 após a transição exigem conferência do instrumento coletivo e das normas complementares do MTE. Para 6x1, cadastre as folgas adicionais necessárias e informe a referência do ACT/CCT. Para 12x36, a apuração não aplica horas extras semanais comuns nem presume adicional de feriado/prorrogação noturna, em razão do tratamento especial do art. 59-A; a validade do regime e os repousos devem ser conferidos com DP/contador.
- O MTE anunciou regulamentação complementar para regimes especiais até 23/11/2026; essa regulamentação deve ser incorporada após publicação. Esta tela não substitui a validação do instrumento coletivo nem certifica a escala.

### Limite regulatório do ponto eletrônico

O módulo é uma **ferramenta de gestão e apuração**, não um REP-P nem um PTRP completo para uso oficial. Marcação via servidor, trilha de auditoria e proteção de registros são controles importantes, mas não bastam para conformidade com a Portaria MTP 671/2021. O REP-P possui requisitos próprios, incluindo registro do programa no INPI; o PTRP deve gerar documentos e arquivos exigidos, como AEJ assinado, espelho de ponto e comprovantes, com integridade, sincronismo com a Hora Legal Brasileira e demais requisitos aplicáveis. Este aplicativo ainda não gera AEJ/AFD/espelho legal nem comprovantes regulamentares, e não possui registro no INPI ou Atestado Técnico e Termo de Responsabilidade. Não deve ser usado como ponto oficial até concluir desenvolvimento, auditoria técnica/jurídica e validação por profissional de DP.
