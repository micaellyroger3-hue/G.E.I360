/* G.E.I360 — Jornada e registro de ponto. Marcação usa horário do servidor. */
(function(){
'use strict';
const baseSetPage=window.setPage;
let rows=[], schedules=[], punches=[], ownEmployee=null, selectedEmployee='';
const el=id=>document.getElementById(id);
const escTime=v=>typeof esc==='function'?esc(String(v??'')):String(v??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const todaySP=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const localStamp=v=>v?new Date(v).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'}):'—';
const canManage=()=>['owner','admin','manager'].includes(companyRole);
const canSchedule=()=>['owner','admin'].includes(companyRole);
async function load(){
 const cid=companyId;
 const [e,s,p]=await Promise.all([
  api('/rest/v1/employees?select=id,full_name,email,employment_status,status,auth_user_id&company_id=eq.'+cid+'&order=full_name.asc'),
  api('/rest/v1/hr_work_schedules?select=*&company_id=eq.'+cid+'&order=effective_from.desc'),
  api('/rest/v1/hr_time_punches?select=*&company_id=eq.'+cid+'&order=punched_at.desc&limit=150')
 ]);
 rows=Array.isArray(e)?e:[];schedules=Array.isArray(s)?s:[];punches=Array.isArray(p)?p:[];
 ownEmployee=rows.find(x=>x.auth_user_id===session.user.id)||null;
 if(!selectedEmployee)selectedEmployee=ownEmployee?.id||rows[0]?.id||'';
}
function selected(){return rows.find(x=>x.id===selectedEmployee)||ownEmployee;}
function lastFor(id){return punches.filter(p=>p.employee_id===id).sort((a,b)=>new Date(b.punched_at)-new Date(a.punched_at))[0]||null;}
function nextTypes(last){
 if(!last||last.punch_type==='saida')return [['entrada','Registrar entrada']];
 if(last.punch_type==='entrada')return [['inicio_intervalo','Iniciar intervalo'],['saida','Registrar saída']];
 if(last.punch_type==='inicio_intervalo')return [['fim_intervalo','Retorno do intervalo']];
 return [['inicio_intervalo','Iniciar outro intervalo'],['saida','Registrar saída']];
}
function scheduleLabel(s){
 const names={'12x36':'12x36','por_hora':'Por hora','fixa':'Horário fixo','6x1':'Escala 6x1','5x2':'Escala 5x2','personalizada':'Personalizada','variavel':'Jornada variável'};
 return names[s.schedule_type]||s.schedule_type;
}
function render(){
 const host=el('view');if(!host)return;
 if(!companyId){host.innerHTML='<div class="notice">Selecione uma empresa para acessar Jornada e Ponto.</div>';return;}
 const managed=canManage();
 const person=selected();
 const list=managed?rows.filter(e=>e.status!=='inactive'):ownEmployee?[ownEmployee]:[];
 const visible=list.length?list.map(e=>'<option value="'+e.id+'" '+(e.id===selectedEmployee?'selected':'')+'>'+escTime(e.full_name)+'</option>').join(''):'';
 const current=person?lastFor(person.id):null;
 const actionButtons=person?nextTypes(current).map(x=>'<button type="button" data-punch="'+x[0]+'">'+x[1]+'</button>').join(''):'';
 const currentSchedule=person?schedules.find(s=>s.employee_id===person.id&&s.effective_from<=todaySP()&&(!s.effective_to||s.effective_to>=todaySP())):null;
 host.innerHTML='<section class="gei-time"><div class="head"><div><h1>Jornada e registro de ponto</h1><span class="muted">Escalas, marcações e acompanhamento de horas</span></div><span class="gei-hr-tag">HORÁRIO DE BRASÍLIA</span></div>'+
 '<div class="notice">Este controle é gerencial e usa horário do servidor. Ainda não é um REP-P/REP-A homologado nem substitui os requisitos legais de registro eletrônico de ponto, folha ou eSocial.</div>'+
 '<div class="gei-hr-panel"><div class="gei-hr-panel-head"><div><h3>Registrar ponto</h3><p>O horário é obtido automaticamente do servidor, sem edição pelo funcionário.</p></div></div>'+
 (managed?'<label class="gei-time-person">Funcionário<select id="geiTimePerson">'+visible+'</select></label>':ownEmployee?'<p><b>'+escTime(ownEmployee.full_name)+'</b></p>':'<div class="notice">Sua conta ainda não está vinculada a uma ficha de funcionário. Use o botão abaixo se seu e-mail de acesso for igual ao e-mail cadastrado na ficha e seu acesso à empresa estiver ativo como funcionário.</div>')+
 (!ownEmployee&&!managed?'<button type="button" id="geiClaimEmployee">Vincular minha ficha de funcionário</button>':'')+
 (person?'<div class="gei-time-status"><span>Última marcação</span><b>'+(current?localStamp(current.punched_at)+' · '+current.punch_type.replace('_',' '):'Nenhuma marcação')+'</b></div><div class="toolbar">'+actionButtons+'</div>':'')+
 '<p class="gei-hr-muted">Dica: marque entrada, início do intervalo, retorno e saída. Se não houver intervalo, o sistema permite registrar a saída após a entrada.</p></div>'+
 (managed?'<div class="gei-hr-panel"><div class="gei-hr-panel-head"><div><h3>Configurar jornada / escala</h3><p>Escolha 12x36, por hora, fixa, 6x1, 5x2 ou personalizada.</p></div></div><form id="geiScheduleForm" class="gei-hr-form">'+
 '<label>Funcionário<select name="employee_id" required>'+rows.map(e=>'<option value="'+e.id+'" '+(e.id===selectedEmployee?'selected':'')+'>'+escTime(e.full_name)+'</option>').join('')+'</select></label>'+
 '<label>Tipo de jornada<select name="schedule_type"><option value="12x36">12x36</option><option value="por_hora">Trabalho por hora</option><option value="fixa">Horário fixo</option><option value="6x1">Escala 6x1</option><option value="5x2">Escala 5x2</option><option value="personalizada">Personalizada</option><option value="variavel">Jornada variável</option></select></label>'+
 '<label>Vigência inicial<input name="effective_from" type="date" required value="'+todaySP()+'"></label><label>Vigência final (opcional)<input name="effective_to" type="date"></label>'+
 '<label>Entrada / início do turno<input name="shift_start" type="time"></label><label>Saída / fim do turno<input name="shift_end" type="time"></label>'+
 '<label>Intervalo previsto (minutos)<input name="break_minutes" type="number" min="0" max="720" value="60"></label><label>Horas semanais previstas<input name="weekly_hours" type="number" min="0" max="168" step=".5" placeholder="Ex.: 44"></label>'+
 '<label>Valor da hora (R$)<input name="hourly_rate" type="number" min="0" step=".01" placeholder="Para contrato/remuneração por hora"></label>'+
 '<label>Data-base do ciclo 12x36<input name="cycle_anchor_date" type="date"></label><label>Dias de trabalho no ciclo<input name="cycle_on_days" type="number" min="1" max="31" value="1"></label><label>Dias de folga no ciclo<input name="cycle_off_days" type="number" min="1" max="31" value="1"></label>'+
 '<label class="wide">Observações<textarea name="notes" rows="2" maxlength="1000" placeholder="Ex.: turno noturno, escala alternada, acordo aplicável"></textarea></label>'+
 '<div class="wide notice">12x36: informe a data-base em que começa um dia de trabalho, além do horário de início e fim do turno. Trabalho por hora: informe o valor/hora e a jornada combinada. O sistema guarda a configuração; o enquadramento contratual e os intervalos legais devem ser validados com o DP/contador.</div><button type="submit" '+(!rows.length?'disabled':'')+'>Salvar escala</button></form></div>':'')+
 '<div class="gei-hr-panel"><h3>Escala cadastrada</h3><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Jornada</th><th>Vigência</th><th>Horário</th><th>Intervalo</th><th>Valor/hora</th></tr></thead><tbody>'+(schedules.map(s=>'<tr><td>'+escTime(rows.find(e=>e.id===s.employee_id)?.full_name||'Funcionário')+'</td><td>'+scheduleLabel(s)+'</td><td>'+s.effective_from+(s.effective_to?' a '+s.effective_to:' em diante')+'</td><td>'+(s.shift_start||'—')+'–'+(s.shift_end||'—')+'</td><td>'+s.break_minutes+' min</td><td>'+(s.hourly_rate==null?'—':Number(s.hourly_rate).toLocaleString('pt-BR',{style:'currency',currency:'BRL'}))+'</td></tr>').join('')||'<tr><td colspan="6">Nenhuma escala configurada.</td></tr>')+'</tbody></table></div></div>'+
 '<div class="gei-hr-panel"><div class="gei-hr-panel-head"><div><h3>Histórico de marcações</h3><p>Registros originais preservados; correções precisam de justificativa e aprovação.</p></div><button type="button" class="alt small" id="geiTimeRefresh">Atualizar</button></div><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Data e hora</th><th>Marcação</th><th>Origem</th></tr></thead><tbody>'+(punches.filter(p=>managed||p.employee_id===ownEmployee?.id).map(p=>'<tr><td>'+escTime(rows.find(e=>e.id===p.employee_id)?.full_name||'Funcionário')+'</td><td>'+localStamp(p.punched_at)+'</td><td>'+p.punch_type.replaceAll('_',' ')+'</td><td>'+(p.source==='app_funcionario'?'Aplicativo do funcionário':'Registro do gestor')+'</td></tr>').join('')||'<tr><td colspan="4">Nenhuma marcação registrada.</td></tr>')+'</tbody></table></div></div></section>';
 const personSelect=el('geiTimePerson');if(personSelect)personSelect.onchange=()=>{selectedEmployee=personSelect.value;render()};
 const refresh=el('geiTimeRefresh');if(refresh)refresh.onclick=async()=>{await load();render()};
 const claim=el('geiClaimEmployee');if(claim)claim.onclick=async()=>{claim.disabled=true;try{const count=await api('/rest/v1/rpc/hr_claim_employee_account',{method:'POST',body:{}});await load();render();alert(Number(count)>0?'Sua ficha foi vinculada. Agora você pode registrar o ponto.':'Não foi encontrada uma ficha com seu e-mail e vínculo de funcionário ativo. Confira com o responsável da empresa.')}catch(e){alert('Não foi possível vincular: '+e.message);claim.disabled=false}};
 host.querySelectorAll('[data-punch]').forEach(b=>b.onclick=async()=>{const target=managed?selectedEmployee:ownEmployee?.id;if(!target)return;const labels={entrada:'Entrada',inicio_intervalo:'Início do intervalo',fim_intervalo:'Retorno do intervalo',saida:'Saída'};if(!confirm('Confirmar '+labels[b.dataset.punch]+' agora? O horário será registrado pelo servidor.'))return;b.disabled=true;try{await api('/rest/v1/rpc/hr_register_time_punch',{method:'POST',body:{p_employee_id:target,p_punch_type:b.dataset.punch}});await load();render()}catch(e){alert('Ponto não registrado: '+e.message);b.disabled=false}});
 const form=el('geiScheduleForm');if(form)form.onsubmit=async ev=>{ev.preventDefault();const f=new FormData(form),v=Object.fromEntries(f.entries());const payload={company_id:companyId,employee_id:v.employee_id,schedule_type:v.schedule_type,effective_from:v.effective_from,effective_to:v.effective_to||null,shift_start:v.shift_start||null,shift_end:v.shift_end||null,break_minutes:Number(v.break_minutes||0),weekly_hours:v.weekly_hours===''?null:Number(v.weekly_hours),hourly_rate:v.hourly_rate===''?null:Number(v.hourly_rate),cycle_on_days:v.schedule_type==='12x36'?1:null,cycle_off_days:v.schedule_type==='12x36'?1:null,cycle_anchor_date:v.schedule_type==='12x36'?(v.cycle_anchor_date||null):null,notes:v.notes||null,created_by:session.user.id};if(v.schedule_type==='12x36'&&!payload.cycle_anchor_date){alert('Informe a data-base do ciclo 12x36.');return;}try{await api('/rest/v1/hr_work_schedules',{method:'POST',body:payload});await load();selectedEmployee=v.employee_id;render();alert('Escala salva.')}catch(e){alert('Não foi possível salvar a escala: '+e.message)}};
}
async function open(){
 if(!companyId){el('view').innerHTML='<div class="notice">Selecione uma empresa para acessar Jornada e Ponto.</div>';return;}
 if(!canManage()&&companyRole!=='employee'){el('view').innerHTML='<div class="notice">Seu perfil não tem permissão para acessar Jornada e Ponto.</div>';return;}
 try{await load();if(!canManage()&&!ownEmployee){render();return;}render()}catch(e){el('view').innerHTML='<div class="err">Não foi possível carregar Jornada e Ponto: '+escTime(e.message)+'</div>'}
}
window.setPage=function(page){if(page==='timeclock'){document.querySelectorAll('[data-page]').forEach(b=>b.classList.toggle('active',b.dataset.page===page));el('pageTitle').textContent='Jornada e ponto';open();return;}return baseSetPage(page)};
document.querySelectorAll('[data-page="timeclock"]').forEach(b=>b.addEventListener('click',()=>window.setPage('timeclock')));
const st=document.createElement('style');st.textContent='.gei-time{display:grid;gap:14px}.gei-time-person{display:grid;gap:6px;max-width:420px;margin:12px 0;font-size:12px;font-weight:700}.gei-time-person select{padding:10px;border:1px solid #dce3ec;border-radius:8px}.gei-time-status{display:flex;justify-content:space-between;gap:10px;padding:12px 0;border-top:1px solid #eef1f5;font-size:12px}.gei-time-status span{color:#718096}.gei-time .toolbar{margin:12px 0 0}.gei-time table{min-width:680px}';document.head.appendChild(st);
})();