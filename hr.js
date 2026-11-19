/* G.E.I360 — RH e gestão de pessoas.
 * Salários e custos ficam em tabelas separadas, protegidas no banco para owner/admin.
 * Os cálculos são estimativas gerenciais, nunca uma folha oficial ou cálculo eSocial.
 */
(function(){
'use strict';
let hrEmployees=[], hrComp=[], hrSettings=null, hrEvents=[], hrPostings=[], hrTab='resumo';
const $hr=id=>document.getElementById(id);
const hrMoney=value=>(Number(value)||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const hrNum=value=>{const n=Number(value);return Number.isFinite(n)?n:0};
const hrEsc=value=>esc(value==null?'':String(value));
const hrToday=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const hrMonth=()=>hrToday().slice(0,7)+'-01';
const hrDate=value=>value?new Date(value+'T12:00:00').toLocaleDateString('pt-BR'):'—';
const hrActive=e=>e.employment_status!=='inativo'&&e.status!=='inactive';
function hrCompOf(id){return hrComp.find(x=>x.employee_id===id)||{salary_base:0,contract_type:'clt',weekly_hours:44,transportation_allowance:0,meal_allowance:0,health_benefit:0,other_benefits:0,work_schedule:''};}
function hrSettingsReady(){return !!hrSettings;}
function hrRateSettings(){
 const s=hrSettings||{};
 let inss=hrNum(s.employer_inss_rate);
 if(s.employer_inss_mode==='mei_3_percent')inss=3;
 if(s.employer_inss_mode==='included_in_das'||s.employer_inss_mode==='not_applicable')inss=0;
 return {fgts:hrNum(s.fgts_rate),inss,rat:hrNum(s.rat_rate),third:hrNum(s.third_party_rate)};
}
function hrCost(c){
 const base=hrNum(c.salary_base),benefits=hrNum(c.transportation_allowance)+hrNum(c.meal_allowance)+hrNum(c.health_benefit)+hrNum(c.other_benefits);
 const clt=c.contract_type==='clt';
 const thirteenth=clt&&hrSettings?.use_13th_provision?base/12:0;
 const vacation=clt&&hrSettings?.use_vacation_provision?base/9:0;
 const payrollBase=base+thirteenth+vacation;
 const rates=hrRateSettings();
 const fgts=clt?payrollBase*rates.fgts/100:0;
 const inss=clt?payrollBase*rates.inss/100:0;
 const rat=clt?payrollBase*rates.rat/100:0;
 const third=clt?payrollBase*rates.third/100:0;
 const total=base+benefits+thirteenth+vacation+fgts+inss+rat+third;
 return {base,benefits,thirteenth,vacation,fgts,inss,rat,third,total,clt,complete:!!hrSettings};
}
async function hrLoad(){
 const q='/rest/v1/';
 const results=await Promise.all([
  api(q+'employees?select=id,full_name,email,phone,job_title,department,admission_date,employment_status,status,created_at&company_id=eq.'+companyId+'&order=created_at.desc'),
  api(q+'employee_compensation?select=*&company_id=eq.'+companyId),
  api(q+'hr_company_settings?select=*&company_id=eq.'+companyId+'&limit=1'),
  api(q+'hr_events?select=*&company_id=eq.'+companyId+'&order=start_date.desc&limit=100'),
  api(q+'hr_cost_postings?select=period,amount,financial_entry_id&company_id=eq.'+companyId+'&order=period.desc&limit=24')
 ]);
 hrEmployees=Array.isArray(results[0])?results[0]:[];
 hrComp=Array.isArray(results[1])?results[1]:[];
 hrSettings=Array.isArray(results[2])?results[2][0]||null:null;
 hrEvents=Array.isArray(results[3])?results[3]:[];
 hrPostings=Array.isArray(results[4])?results[4]:[];
}
function hrTabs(){
 return '<div class="gei-hr-tabs">'+[['resumo','Resumo'],['equipe','Equipe'],['custos','Custos e encargos'],['eventos','Férias e eventos'],['config','Configuração']].map(x=>'<button type="button" class="'+(hrTab===x[0]?'active':'')+'" data-hr-tab="'+x[0]+'">'+x[1]+'</button>').join('')+'</div>';
}
function hrHeader(subtitle){
 $('pageTitle').textContent='RH e equipe';
 $('view').innerHTML='<section class="gei-hr"><div class="gei-hr-head"><div><h1>RH e gestão de pessoas</h1><p>'+hrEsc(subtitle||'Equipe, custos e rotinas de pessoal em um só lugar')+'</p></div><span class="gei-hr-tag">ACESSO RESTRITO</span></div>'+hrTabs()+'<div id="geiHrContent"></div></section>';
 document.querySelectorAll('[data-hr-tab]').forEach(b=>b.onclick=()=>{hrTab=b.dataset.hrTab;hrRenderTab()});
}
function hrKpi(label,value,detail){
 return '<article class="gei-hr-kpi"><span>'+label+'</span><strong>'+value+'</strong><small>'+detail+'</small></article>';
}
function hrSummary(){
 const active=hrEmployees.filter(hrActive);
 const total=active.reduce((sum,e)=>sum+hrCost(hrCompOf(e.id)).total,0);
 const payroll=active.reduce((sum,e)=>sum+hrNum(hrCompOf(e.id).salary_base),0);
 const eventCount=hrEvents.filter(e=>e.status!=='cancelado'&&e.status!=='concluido').length;
 const missing=active.filter(e=>!hrComp.some(c=>c.employee_id===e.id)).length;
 const otherContracts=active.filter(e=>hrCompOf(e.id).contract_type!=='clt').length;
 const meiOverLimit=hrSettings?.tax_regime==='mei'&&active.length>1;
 const rates=hrRateSettings();
 const posted=hrPostings.find(p=>p.period===hrMonth());
 return '<div class="gei-hr-kpis">'+hrKpi('Funcionários ativos',active.length,'Vínculos ativos')+hrKpi('Salários-base',hrMoney(payroll),'Total bruto mensal')+hrKpi('Custo estimado',hrMoney(total),'Salários, benefícios e encargos')+hrKpi('Eventos em aberto',eventCount,'Férias, ausências e afastamentos')+'</div>'+
  (!hrSettings?'<div class="notice">Configure o regime tributário e os encargos em <b>Configuração</b>. Sem essa informação, o custo total é apenas parcial e não deve ser usado como valor final.</div>':'')+
  (missing?'<div class="notice">'+missing+' funcionário(s) ativo(s) ainda não têm salário e benefícios cadastrados.</div>':'')+
  (meiOverLimit?'<div class="err">Atenção: o cadastro mostra mais de um funcionário ativo. O MEI tem limite legal de um empregado; revise o enquadramento antes de usar esta estimativa.</div>':'')+
  (otherContracts?'<div class="notice">'+otherContracts+' vínculo(s) não CLT: o sistema soma remuneração e benefícios, mas não presume encargos específicos desses contratos.</div>':'')+
  '<div class="gei-hr-grid"><section class="gei-hr-panel"><h3>Composição estimada da equipe</h3><p>Valores mensais estimados com base nos dados cadastrados.</p><div class="gei-hr-breakdown"><div><span>Salários-base</span><b>'+hrMoney(payroll)+'</b></div><div><span>Benefícios</span><b>'+hrMoney(active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).benefits,0))+'</b></div><div><span>FGTS estimado</span><b>'+hrMoney(active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).fgts,0))+'</b></div><div><span>INSS patronal estimado</span><b>'+hrMoney(active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).inss,0))+'</b></div><div><span>Provisões 13º + férias</span><b>'+hrMoney(active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).thirteenth+hrCost(hrCompOf(e.id)).vacation,0))+'</b></div><div class="total"><span>Custo mensal estimado</span><b>'+hrMoney(total)+'</b></div></div></section>'+
  '<section class="gei-hr-panel"><h3>Próximas providências</h3><div class="gei-hr-check"><div><b>1.</b> Complete salário e benefícios da equipe</div><div><b>2.</b> Confirme regime tributário e encargos com a contabilidade</div><div><b>3.</b> Registre férias, ausências e afastamentos</div><div><b>4.</b> Revise o custo antes de lançar no Financeiro</div></div><p class="gei-hr-muted">As taxas exibidas dependem da configuração tributária da empresa. Não há transmissão de folha ao eSocial nem geração de guias nesta versão.</p></section></div>'+
  '<section class="gei-hr-panel"><div class="gei-hr-panel-head"><div><h3>Lançamento no Financeiro</h3><p>Registre uma única despesa mensal com o custo estimado da equipe.</p></div></div><div class="gei-hr-finance-row"><div><b>'+hrMoney(total)+'</b><small>Referência '+hrDate(hrMonth())+'</small></div>'+(posted?'<span class="gei-hr-posted">Já lançado no Financeiro</span>':'<button type="button" id="hrPostCost" '+(!hrSettings||!active.length||total<=0?'disabled':'')+'>Lançar custo estimado</button>')+'</div><p class="gei-hr-muted">O lançamento é uma despesa gerencial pendente. Confirme o pagamento no Financeiro quando ocorrer. O sistema bloqueia um segundo lançamento para o mesmo mês.</p></section>';
}
function hrEmployeeRows(){
 return hrEmployees.map(e=>{
  const c=hrCompOf(e.id),cost=hrCost(c);
  return '<tr><td><b>'+hrEsc(e.full_name)+'</b><small>'+hrEsc(e.email||'')+'</small></td><td>'+hrEsc(e.job_title||'—')+'</td><td>'+hrEsc(e.department||'—')+'</td><td>'+hrDate(e.admission_date)+'</td><td>'+hrEsc(e.employment_status||'ativo')+'</td><td>'+hrMoney(c.salary_base)+'</td><td><b>'+hrMoney(cost.total)+'</b></td><td><div class="actions"><button class="alt small" data-hr-edit="'+e.id+'">Editar</button><button class="alt small" data-hr-event="'+e.id+'">Evento</button></div></td></tr>';
 }).join('');
}
function hrTeam(){
 return '<div class="gei-hr-toolbar"><input id="hrSearch" class="search" placeholder="Pesquisar nome, cargo ou departamento"><button type="button" id="hrNewEmployee">+ Novo funcionário</button><button type="button" class="alt" id="hrExport">Exportar CSV</button></div>'+
  '<div class="gei-hr-panel"><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Cargo</th><th>Departamento</th><th>Admissão</th><th>Situação</th><th>Salário</th><th>Custo estimado</th><th>Ações</th></tr></thead><tbody id="hrEmployeeRows">'+(hrEmployees.length?hrEmployeeRows():'<tr><td colspan="8">Nenhum funcionário cadastrado.</td></tr>')+'</tbody></table></div></div>'+
  '<div class="gei-hr-muted">Remuneração e custo são visíveis somente para proprietário e administrador. Cadastros básicos antigos foram preservados; complete os dados salariais de cada pessoa.</div>';
}
function hrCostTable(){
 const active=hrEmployees.filter(hrActive);
 const rows=active.map(e=>{
  const c=hrCompOf(e.id),v=hrCost(c);
  return '<tr><td>'+hrEsc(e.full_name)+'</td><td>'+hrMoney(v.base)+'</td><td>'+hrMoney(v.benefits)+'</td><td>'+hrMoney(v.fgts)+'</td><td>'+hrMoney(v.inss)+'</td><td>'+hrMoney(v.rat+v.third)+'</td><td>'+hrMoney(v.thirteenth+v.vacation)+'</td><td><b>'+hrMoney(v.total)+'</b></td></tr>';
 }).join('');
 const total=active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).total,0);
 return '<div class="notice">Estimativa gerencial. Para CLT, considera salário, benefícios informados, FGTS, INSS patronal conforme configuração, RAT/terceiros informados e provisões de 13º/férias. Não inclui automaticamente FAP, convenção coletiva, horas extras, adicionais, rescisão, exames, SST ou outros itens específicos.</div>'+
  (!hrSettings?'<div class="err">Configure o regime tributário antes de considerar os encargos.</div>':'')+
  (hrSettings?.tax_regime==='mei'&&active.length>1?'<div class="err">O MEI tem limite legal de um empregado. Há mais de um vínculo ativo no cadastro; valide antes de usar o cálculo.</div>':'')+
  (active.some(e=>hrCompOf(e.id).contract_type!=='clt')?'<div class="notice">Há vínculos não CLT. Os encargos específicos desses contratos não são calculados automaticamente.</div>':'')+
  '<div class="gei-hr-panel"><div class="gei-hr-panel-head"><div><h3>Custo por funcionário ativo</h3><p>Valores mensais calculados a partir da remuneração cadastrada.</p></div><b>'+hrMoney(total)+'</b></div><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Salário</th><th>Benefícios</th><th>FGTS</th><th>INSS patronal</th><th>RAT + terceiros</th><th>Provisões</th><th>Custo total</th></tr></thead><tbody>'+(rows||'<tr><td colspan="8">Nenhum funcionário ativo.</td></tr>')+'</tbody></table></div><button type="button" class="alt" id="hrExportCosts" style="margin-top:12px">Exportar custos CSV</button></div>'+
  '<div class="gei-hr-muted">Regra especial: MEI usa a contribuição patronal de 3% e FGTS de 8% como estimativa para o único empregado permitido. O sistema alerta se houver mais de um ativo. Confirme o enquadramento, o piso salarial e as obrigações com seu contador.</div>';
}
function hrEventRows(){
 const labels={ferias:'Férias',ausencia:'Ausência',afastamento:'Afastamento',atestado:'Atestado',advertencia:'Advertência',alteracao_cargo:'Alteração de cargo',outro:'Outro'};
 return hrEvents.map(e=>{
  const person=hrEmployees.find(x=>x.id===e.employee_id);
  return '<tr><td>'+hrEsc(person?.full_name||'Funcionário')+'</td><td>'+labels[e.event_type]+'</td><td>'+hrDate(e.start_date)+'</td><td>'+hrDate(e.end_date)+'</td><td>'+hrEsc(e.status)+'</td><td>'+hrEsc(e.notes||'')+'</td></tr>';
 }).join('');
}
function hrEventsView(){
 return '<div class="gei-hr-panel"><h3>Registrar férias, ausência ou ocorrência</h3><p>Não registre diagnóstico, CID ou detalhes clínicos. Guarde documentos médicos em local apropriado e com acesso restrito.</p><form id="hrEventForm" class="gei-hr-form"><label>Funcionário<select name="employee_id" required>'+hrEmployees.map(e=>'<option value="'+e.id+'">'+hrEsc(e.full_name)+'</option>').join('')+'</select></label><label>Tipo<select name="event_type"><option value="ferias">Férias</option><option value="ausencia">Ausência</option><option value="afastamento">Afastamento</option><option value="atestado">Atestado</option><option value="advertencia">Advertência</option><option value="alteracao_cargo">Alteração de cargo</option><option value="outro">Outro</option></select></label><label>Data inicial<input name="start_date" type="date" required value="'+hrToday()+'"></label><label>Data final<input name="end_date" type="date"></label><label>Situação<select name="status"><option value="planejado">Planejado</option><option value="em_andamento">Em andamento</option><option value="concluido">Concluído</option><option value="cancelado">Cancelado</option></select></label><label class="wide">Observações<textarea name="notes" rows="2" maxlength="1000" placeholder="Informações administrativas, sem dados médicos sensíveis"></textarea></label><button type="submit" '+(!hrEmployees.length?'disabled':'')+'>Salvar evento</button></form></div>'+
  '<div class="gei-hr-panel"><h3>Histórico de eventos</h3><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Tipo</th><th>Início</th><th>Fim</th><th>Situação</th><th>Observações</th></tr></thead><tbody>'+(hrEventRows()||'<tr><td colspan="6">Nenhum evento registrado.</td></tr>')+'</tbody></table></div></div>';
}
function hrConfig(){
 const s=hrSettings||{tax_regime:'',simples_annex:'',employer_inss_mode:'included_in_das',employer_inss_rate:0,fgts_rate:8,rat_rate:0,third_party_rate:0,use_13th_provision:true,use_vacation_provision:true,notes:''};
 return '<div class="gei-hr-panel"><h3>Parâmetros trabalhistas e tributários</h3><p>Informe os parâmetros confirmados para esta empresa. O sistema não presume alíquotas de terceiros nem RAT/FAP.</p><form id="hrSettingsForm" class="gei-hr-form">'+
  '<label>Regime tributário<select name="tax_regime" required><option value="">Selecione</option><option value="mei" '+(s.tax_regime==='mei'?'selected':'')+'>MEI</option><option value="simples_nacional" '+(s.tax_regime==='simples_nacional'?'selected':'')+'>Simples Nacional</option><option value="lucro_presumido" '+(s.tax_regime==='lucro_presumido'?'selected':'')+'>Lucro Presumido</option><option value="lucro_real" '+(s.tax_regime==='lucro_real'?'selected':'')+'>Lucro Real</option><option value="outro" '+(s.tax_regime==='outro'?'selected':'')+'>Outro</option></select></label>'+
  '<label>Anexo do Simples<select name="simples_annex"><option value="">Não se aplica</option>'+['I','II','III','IV','V'].map(x=>'<option value="'+x+'" '+(s.simples_annex===x?'selected':'')+'>Anexo '+x+'</option>').join('')+'</select></label>'+
  '<label>INSS patronal<select name="employer_inss_mode"><option value="mei_3_percent" '+(s.employer_inss_mode==='mei_3_percent'?'selected':'')+'>MEI — 3%</option><option value="included_in_das" '+(s.employer_inss_mode==='included_in_das'?'selected':'')+'>Incluído no DAS</option><option value="separate" '+(s.employer_inss_mode==='separate'?'selected':'')+'>Recolhido à parte</option><option value="custom" '+(s.employer_inss_mode==='custom'?'selected':'')+'>Alíquota personalizada</option><option value="not_applicable" '+(s.employer_inss_mode==='not_applicable'?'selected':'')+'>Não aplicável</option></select></label>'+
  '<label>Alíquota INSS patronal (%)<input name="employer_inss_rate" type="number" min="0" max="100" step="0.0001" value="'+hrNum(s.employer_inss_rate)+'"></label>'+
  '<label>FGTS (%)<input name="fgts_rate" type="number" min="0" max="100" step="0.0001" value="'+hrNum(s.fgts_rate)+'"></label>'+
  '<label>RAT/SAT (%)<input name="rat_rate" type="number" min="0" max="100" step="0.0001" value="'+hrNum(s.rat_rate)+'"></label>'+
  '<label>Terceiros / Sistema S (%)<input name="third_party_rate" type="number" min="0" max="100" step="0.0001" value="'+hrNum(s.third_party_rate)+'"></label>'+
  '<label class="check"><input type="checkbox" name="use_13th_provision" '+(s.use_13th_provision?'checked':'')+'> Incluir provisão mensal de 13º</label>'+
  '<label class="check"><input type="checkbox" name="use_vacation_provision" '+(s.use_vacation_provision?'checked':'')+'> Incluir provisão mensal de férias + 1/3</label>'+
  '<label class="wide">Observações / fonte das alíquotas<textarea name="notes" rows="3" maxlength="1500" placeholder="Ex.: parâmetros confirmados com contador em DD/MM/AAAA">'+hrEsc(s.notes||'')+'</textarea></label>'+
  '<div class="wide notice">Atenção: MEI possui regras próprias e limite legal de contratação. No Simples Nacional, a contribuição patronal previdenciária depende do anexo e da atividade (Anexo IV é tratado separadamente). RAT, FAP e terceiros variam conforme enquadramento. Confirme com a contabilidade antes de salvar.</div><button type="submit">Salvar configuração</button></form></div>';
}
async function hrRenderTab(){
 const host=$hr('geiHrContent');if(!host)return;
 if(hrTab==='resumo')host.innerHTML=hrSummary();
 if(hrTab==='equipe')host.innerHTML=hrTeam();
 if(hrTab==='custos')host.innerHTML=hrCostTable();
 if(hrTab==='eventos')host.innerHTML=hrEventsView();
 if(hrTab==='config')host.innerHTML=hrConfig();
 hrBind();
}
function hrEmployeeForm(id){
 const e=hrEmployees.find(x=>x.id===id)||{};
 const c=hrCompOf(id||'');
 const isEdit=!!id;
 const form=document.createElement('div');
 form.className='gei-hr-modal';
 form.innerHTML='<div class="gei-hr-dialog"><div class="gei-hr-dialog-head"><h2>'+(isEdit?'Editar funcionário':'Novo funcionário')+'</h2><button type="button" class="alt small" id="hrCloseModal">Fechar</button></div><form id="hrEmployeeForm" class="gei-hr-form">'+
  '<input type="hidden" name="id" value="'+(id||'')+'"><label>Nome completo<input name="full_name" required maxlength="120" value="'+hrEsc(e.full_name||'')+'"></label><label>E-mail<input name="email" type="email" value="'+hrEsc(e.email||'')+'"></label><label>Telefone<input name="phone" maxlength="30" value="'+hrEsc(e.phone||'')+'"></label><label>Cargo<input name="job_title" maxlength="80" value="'+hrEsc(e.job_title||'')+'"></label><label>Departamento<input name="department" maxlength="80" value="'+hrEsc(e.department||'')+'"></label><label>Data de admissão<input name="admission_date" type="date" value="'+(e.admission_date||'')+'"></label><label>Situação<select name="employment_status"><option value="ativo" '+(e.employment_status==='ativo'?'selected':'')+'>Ativo</option><option value="afastado" '+(e.employment_status==='afastado'?'selected':'')+'>Afastado</option><option value="inativo" '+(e.employment_status==='inativo'?'selected':'')+'>Inativo</option></select></label><label>Tipo de contratação<select name="contract_type"><option value="clt" '+(c.contract_type==='clt'?'selected':'')+'>CLT</option><option value="aprendiz" '+(c.contract_type==='aprendiz'?'selected':'')+'>Aprendiz</option><option value="estagio" '+(c.contract_type==='estagio'?'selected':'')+'>Estágio</option><option value="autonomo" '+(c.contract_type==='autonomo'?'selected':'')+'>Autônomo</option><option value="pj" '+(c.contract_type==='pj'?'selected':'')+'>Pessoa jurídica (PJ)</option></select></label><label>Salário / remuneração mensal (R$)<input name="salary_base" type="number" min="0" step="0.01" required value="'+hrNum(c.salary_base)+'"></label><label>Jornada semanal (horas)<input name="weekly_hours" type="number" min="0" max="168" step="0.5" value="'+hrNum(c.weekly_hours||44)+'"></label><label class="wide">Escala / horário<input name="work_schedule" maxlength="160" placeholder="Ex.: 12x36, 07h às 19h" value="'+hrEsc(c.work_schedule||'')+'"></label><label>Vale-transporte mensal (R$)<input name="transportation_allowance" type="number" min="0" step="0.01" value="'+hrNum(c.transportation_allowance)+'"></label><label>Alimentação mensal (R$)<input name="meal_allowance" type="number" min="0" step="0.01" value="'+hrNum(c.meal_allowance)+'"></label><label>Plano de saúde mensal (R$)<input name="health_benefit" type="number" min="0" step="0.01" value="'+hrNum(c.health_benefit)+'"></label><label>Outros benefícios mensais (R$)<input name="other_benefits" type="number" min="0" step="0.01" value="'+hrNum(c.other_benefits)+'"></label><label class="wide">Observações de RH<textarea name="notes" rows="2" maxlength="1000">'+hrEsc(c.notes||'')+'</textarea></label><div class="wide notice">O salário é armazenado em área separada e visível somente para proprietário e administrador. Para contratos que não sejam CLT, o sistema não presume encargos trabalhistas automaticamente.</div><div class="wide gei-hr-actions"><button type="submit">Salvar funcionário</button><button type="button" class="alt" id="hrCancelModal">Cancelar</button></div></form></div>';
 document.body.appendChild(form);
 const close=()=>form.remove();
 $hr('hrCloseModal').onclick=close;$hr('hrCancelModal').onclick=close;
 $hr('hrEmployeeForm').onsubmit=async ev=>{
  ev.preventDefault();const f=new FormData(ev.currentTarget);const vals=Object.fromEntries(f.entries());
  const employee={full_name:String(vals.full_name).trim(),email:String(vals.email||'').trim()||null,phone:String(vals.phone||'').trim()||null,job_title:String(vals.job_title||'').trim()||null,department:String(vals.department||'').trim()||null,admission_date:vals.admission_date||null,employment_status:vals.employment_status,status:vals.employment_status==='inativo'?'inactive':'active'};
  const comp={salary_base:hrNum(vals.salary_base),contract_type:vals.contract_type,weekly_hours:vals.weekly_hours===''?null:hrNum(vals.weekly_hours),work_schedule:String(vals.work_schedule||'').trim()||null,transportation_allowance:hrNum(vals.transportation_allowance),meal_allowance:hrNum(vals.meal_allowance),health_benefit:hrNum(vals.health_benefit),other_benefits:hrNum(vals.other_benefits),notes:String(vals.notes||'').trim()||null};
  try{
   let employeeId=id;
   if(id)await api('/rest/v1/employees?id=eq.'+id,{method:'PATCH',body:employee});
   else{const result=await api('/rest/v1/employees',{method:'POST',headers:{Prefer:'return=representation'},body:{...employee,company_id:companyId,created_by:session.user.id}});employeeId=result?.[0]?.id;if(!employeeId)throw Error('O banco não retornou o cadastro do funcionário.');}
   const existing=hrComp.find(x=>x.employee_id===employeeId);
   if(existing)await api('/rest/v1/employee_compensation?id=eq.'+existing.id,{method:'PATCH',body:{...comp,updated_at:new Date().toISOString()}});
   else await api('/rest/v1/employee_compensation',{method:'POST',body:{...comp,company_id:companyId,employee_id:employeeId,created_by:session.user.id}});
   close();await hrLoad();await hrRenderTab();
  }catch(error){alert('Não foi possível salvar o funcionário: '+error.message)}
 };
}
function hrBind(){
 const add=$hr('hrNewEmployee');if(add)add.onclick=()=>hrEmployeeForm('');
 const search=$hr('hrSearch');if(search)search.oninput=()=>{const q=search.value.toLocaleLowerCase('pt-BR');const filtered=hrEmployees.filter(e=>[e.full_name,e.job_title,e.department].join(' ').toLocaleLowerCase('pt-BR').includes(q));$hr('hrEmployeeRows').innerHTML=filtered.length?filtered.map(e=>{const c=hrCompOf(e.id);return '<tr><td><b>'+hrEsc(e.full_name)+'</b><small>'+hrEsc(e.email||'')+'</small></td><td>'+hrEsc(e.job_title||'—')+'</td><td>'+hrEsc(e.department||'—')+'</td><td>'+hrDate(e.admission_date)+'</td><td>'+hrEsc(e.employment_status||'ativo')+'</td><td>'+hrMoney(c.salary_base)+'</td><td><b>'+hrMoney(hrCost(c).total)+'</b></td><td><button class="alt small" data-hr-edit="'+e.id+'">Editar</button></td></tr>'}).join(''):'<tr><td colspan="8">Nenhum resultado.</td></tr>';hrBindEdit();};
 hrBindEdit();
 const exportBtn=$hr('hrExport');if(exportBtn)exportBtn.onclick=()=>hrCsv('equipe');
 const costExport=$hr('hrExportCosts');if(costExport)costExport.onclick=()=>hrCsv('custos');
 const eventForm=$hr('hrEventForm');if(eventForm)eventForm.onsubmit=async ev=>{ev.preventDefault();const f=new FormData(eventForm);const p=Object.fromEntries(f.entries());if(!p.end_date)p.end_date=null;try{await api('/rest/v1/hr_events',{method:'POST',body:{...p,company_id:companyId,created_by:session.user.id}});await hrLoad();await hrRenderTab()}catch(error){alert('Não foi possível salvar o evento: '+error.message)}};
 const settingsForm=$hr('hrSettingsForm');if(settingsForm)settingsForm.onsubmit=async ev=>{ev.preventDefault();const f=new FormData(settingsForm);const p=Object.fromEntries(f.entries());p.use_13th_provision=f.has('use_13th_provision');p.use_vacation_provision=f.has('use_vacation_provision');for(const k of ['employer_inss_rate','fgts_rate','rat_rate','third_party_rate'])p[k]=hrNum(p[k]);if(p.simples_annex==='')p.simples_annex=null;
  if(p.tax_regime==='mei'){p.employer_inss_mode='mei_3_percent';p.employer_inss_rate=3;p.fgts_rate=8;p.simples_annex=null;}
  if(p.tax_regime==='simples_nacional'&&p.simples_annex!=='IV'){p.employer_inss_mode='included_in_das';p.employer_inss_rate=0;}
  if(p.tax_regime==='simples_nacional'&&p.simples_annex==='IV'&&p.employer_inss_mode==='included_in_das'){p.employer_inss_mode='separate';if(!p.employer_inss_rate)p.employer_inss_rate=20;}
  if(['lucro_presumido','lucro_real'].includes(p.tax_regime)&&p.employer_inss_mode==='included_in_das'){p.employer_inss_mode='separate';if(!p.employer_inss_rate)p.employer_inss_rate=20;}
  try{if(hrSettings)await api('/rest/v1/hr_company_settings?id=eq.'+hrSettings.id,{method:'PATCH',body:{...p,updated_at:new Date().toISOString()}});else await api('/rest/v1/hr_company_settings',{method:'POST',body:{...p,company_id:companyId,created_by:session.user.id}});await hrLoad();await hrRenderTab();}catch(error){alert('Não foi possível salvar a configuração: '+error.message)}
 };
 const post=$hr('hrPostCost');if(post)post.onclick=async()=>{const active=hrEmployees.filter(hrActive);const total=active.reduce((s,e)=>s+hrCost(hrCompOf(e.id)).total,0);if(!confirm('Lançar '+hrMoney(total)+' como despesa estimada de folha no Financeiro, com vencimento no primeiro dia deste mês?'))return;post.disabled=true;try{await api('/rest/v1/rpc/gei_post_hr_monthly_cost',{method:'POST',body:{p_company_id:companyId,p_period:hrMonth(),p_amount:Number(total.toFixed(2)),p_notes:'Estimativa gerencial calculada no módulo RH do G.E.I360. Não substitui folha oficial.'}});await hrLoad();await hrRenderTab();alert('Custo estimado lançado no Financeiro. Confira a despesa na área Financeiro.')}catch(error){alert(error.message);post.disabled=false}};
}
function hrBindEdit(){
 document.querySelectorAll('[data-hr-edit]').forEach(b=>{b.onclick=()=>hrEmployeeForm(b.dataset.hrEdit)});
 document.querySelectorAll('[data-hr-event]').forEach(b=>{b.onclick=()=>{hrTab='eventos';hrRenderTab().then(()=>{const s=document.querySelector('#hrEventForm select[name="employee_id"]');if(s)s.value=b.dataset.hrEvent})}});
}
function hrCsv(kind){
 let rows=[];
 if(kind==='equipe')rows=[['Nome','Cargo','Departamento','Admissão','Situação','Salário mensal','Benefícios','Custo estimado'],...hrEmployees.map(e=>{const c=hrCompOf(e.id),v=hrCost(c);return [e.full_name,e.job_title,e.department,e.admission_date,e.employment_status,c.salary_base,v.benefits,v.total]})];
 else rows=[['Funcionário','Salário','Benefícios','FGTS','INSS patronal','RAT','Terceiros','13º','Férias + 1/3','Custo total'],...hrEmployees.filter(hrActive).map(e=>{const v=hrCost(hrCompOf(e.id));return [e.full_name,v.base,v.benefits,v.fgts,v.inss,v.rat,v.third,v.thirteenth,v.vacation,v.total]})];
 const csv='\uFEFF'+rows.map(row=>row.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(';')).join('\r\n');
 const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download='gei360-rh-'+kind+'-'+hrToday()+'.csv';document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);
}
async function hrRender(){
 if(!companyId){erpPageShell('Empresa necessária','Selecione uma empresa para acessar o RH.','<div class="notice">Acesse Minha empresa e selecione ou cadastre uma empresa.</div>');return;}
 if(!['owner','admin'].includes(companyRole)){return hrBaseSetPage('employees');}
 try{await hrLoad();hrHeader();await hrRenderTab();}
 catch(error){erpPageShell('RH e gestão de pessoas','Equipe, remuneração e rotinas de pessoal','<div class="err">Não foi possível carregar o RH: '+hrEsc(error.message)+'</div>');}
}
const hrBaseSetPage=setPage;
setPage=async function(page){
 if(page==='employees' && typeof geiModuleCatalog!=='undefined' && geiModuleCatalog.length && !geiPageIsEnabled('employees')) return hrBaseSetPage(page);
 if(page==='employees'){await hrRender();return;}
 return hrBaseSetPage(page);
};
if(typeof GEI_MODULE_LABELS!=='undefined')GEI_MODULE_LABELS.employees='RH e equipe';
const style=document.createElement('style');
style.textContent='.gei-hr{display:grid;gap:14px}.gei-hr-head{display:flex;align-items:center;justify-content:space-between;gap:12px}.gei-hr-head h1{margin:0;font-size:24px}.gei-hr-head p,.gei-hr-panel>p{margin:5px 0 0;color:#718096;font-size:12px}.gei-hr-tag,.gei-hr-posted{background:#edf7f4;color:#17664e;padding:6px 9px;border-radius:7px;font-size:10px;font-weight:800}.gei-hr-tabs{display:flex;gap:6px;overflow:auto;padding-bottom:3px}.gei-hr-tabs button{white-space:nowrap;background:#eaf0f5;color:#263449}.gei-hr-tabs button.active{background:#16866d;color:white}.gei-hr-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.gei-hr-kpi,.gei-hr-panel{background:#fff;border:1px solid #e5eaf1;border-radius:12px;padding:15px;min-width:0}.gei-hr-kpi{display:grid;gap:6px}.gei-hr-kpi span,.gei-hr-kpi small{color:#718096;font-size:11px}.gei-hr-kpi strong{font-size:20px}.gei-hr-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.gei-hr-panel h3{margin:0 0 5px;font-size:14px}.gei-hr-breakdown{display:grid;gap:0;margin-top:12px}.gei-hr-breakdown>div{display:flex;justify-content:space-between;gap:10px;padding:9px 0;border-bottom:1px solid #eef1f5;font-size:12px}.gei-hr-breakdown .total{font-weight:800;border-bottom:0}.gei-hr-check{display:grid;gap:11px;margin:16px 0;font-size:12px}.gei-hr-check b{color:#16866d;margin-right:7px}.gei-hr-muted{font-size:11px;color:#718096;line-height:1.5;margin:9px 0}.gei-hr-panel-head,.gei-hr-finance-row{display:flex;justify-content:space-between;align-items:center;gap:12px}.gei-hr-finance-row>div{display:grid;gap:4px}.gei-hr-finance-row>div b{font-size:20px}.gei-hr-finance-row small{font-size:11px;color:#718096}.gei-hr-toolbar{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}.gei-hr-toolbar .search{flex:1}.gei-hr-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:14px}.gei-hr-form label{display:grid;gap:5px;font-size:11px;font-weight:700;color:#526174}.gei-hr-form input,.gei-hr-form select,.gei-hr-form textarea{width:100%;padding:10px;border:1px solid #dce3ec;border-radius:8px;font:inherit;color:#172033;background:white}.gei-hr-form .wide{grid-column:1/-1}.gei-hr-form label.check{display:flex;align-items:center;gap:8px}.gei-hr-form label.check input{width:auto}.gei-hr-actions{display:flex;gap:8px;flex-wrap:wrap}.gei-hr-modal{position:fixed;inset:0;z-index:1200;background:#0009;display:grid;place-items:center;padding:12px}.gei-hr-dialog{background:white;border-radius:14px;padding:18px;width:min(760px,100%);max-height:94vh;overflow:auto}.gei-hr-dialog-head{display:flex;justify-content:space-between;align-items:center;gap:10px}.gei-hr-dialog-head h2{font-size:18px;margin:0}.gei-hr table{min-width:850px}.gei-hr td small{display:block;color:#718096;font-size:10px;margin-top:3px}@media(max-width:850px){.gei-hr-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.gei-hr-grid{grid-template-columns:1fr}}@media(max-width:520px){.gei-hr-head{align-items:flex-start}.gei-hr-head h1{font-size:20px}.gei-hr-form{grid-template-columns:1fr}.gei-hr-form .wide{grid-column:auto}.gei-hr-kpi strong{font-size:17px}.gei-hr-finance-row{align-items:flex-start;flex-direction:column}}';
document.head.appendChild(style);
})();