/* G.E.I360 — Apuração gerencial de jornada, adicionais, ocorrências e fechamento.
 * O tratamento preserva marcações originais; não se declara REP-P/REP-A certificado.
 */
(function(){
'use strict';
const baseSetPage=window.setPage;
const $=id=>document.getElementById(id);
const escH=s=>esc(String(s??''));
function statutoryWeeklyCapH(date){if(date<'2026-12-16')return 2640;if(date<'2027-12-16')return 2520;return 2400}
const todayH=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const monthH=()=>todayH().slice(0,7);
const moneyH=n=>Number(n||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const minsH=n=>{n=Math.round(Number(n)||0);return (n<0?'-':'')+Math.floor(Math.abs(n)/60)+'h '+String(Math.abs(n)%60).padStart(2,'0')+'min'};
const dateLabelH=d=>d?new Date(d+'T12:00:00-03:00').toLocaleDateString('pt-BR'):'—';
const adminH=()=>['owner','admin'].includes(companyRole);
let dataH={employees:[],schedules:[],punches:[],comp:[],rules:null,holidays:[],scheduleExceptions:[],occurrences:[],bank:[],periods:[]},monthPick=monthH();
const apiH=(table,query='')=>api('/rest/v1/'+table+'?'+query);
async function apiAllH(table,query=''){const all=[],size=500;let offset=0;while(true){const rows=await apiH(table,query+(query?'&':'')+'limit='+size+'&offset='+offset);if(!Array.isArray(rows))throw Error('Resposta inválida ao consultar '+table+'.');all.push(...rows);if(rows.length<size)break;offset+=size}return all}
function zonedPartsH(value){
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(new Date(value));
 const get=t=>parts.find(x=>x.type===t)?.value||'00';
 return {date:get('year')+'-'+get('month')+'-'+get('day'),hour:Number(get('hour')),minute:Number(get('minute'))};
}
function scheduleForH(employeeId,date){
 return dataH.schedules.find(s=>s.employee_id===employeeId&&s.effective_from<=date&&(!s.effective_to||s.effective_to>=date))||null;
}
function baseExpectedH(s,date){
 if(!s||s.schedule_type==='variavel'||s.schedule_type==='por_hora')return false;
 const d=new Date(date+'T12:00:00-03:00'),dow=d.getDay()===0?7:d.getDay();
 if(s.schedule_type==='12x36'){
  if(!s.cycle_anchor_date)return false;
  const a=new Date(s.cycle_anchor_date+'T12:00:00-03:00');
  const delta=Math.round((d-a)/86400000),cycle=Math.max(1,Number(s.cycle_on_days||1)+Number(s.cycle_off_days||1));
  return ((delta%cycle)+cycle)%cycle<Number(s.cycle_on_days||1);
 }
 const days=Array.isArray(s.weekdays)&&s.weekdays.length?s.weekdays:(s.schedule_type==='5x2'?[1,2,3,4,5]:s.schedule_type==='6x1'?[1,2,3,4,5,6]:[1,2,3,4,5]);
 return days.includes(dow);
}
function expectedH(s,date,employeeId){
 const exception=dataH.scheduleExceptions.find(x=>x.employee_id===(employeeId||s?.employee_id)&&x.exception_date===date);
 if(exception?.exception_type==='extra_rest')return false;
 if(exception?.exception_type==='extra_work')return true;
 return baseExpectedH(s,date);
}
function restComplianceH(employeeId,sessions){
 if(monthPick<'2026-12')return null;
 const start=monthPick==='2026-12'?'2026-12-16':monthPick+'-01';
 const end=new Date(Number(monthPick.slice(0,4)),Number(monthPick.slice(5,7)),0).toISOString().slice(0,10);
 const days=Math.max(0,Math.round((new Date(end+'T12:00:00-03:00')-new Date(start+'T12:00:00-03:00'))/86400000)+1);
 const monthSchedules=dataH.schedules.filter(s=>s.employee_id===employeeId&&s.effective_from<=end&&(!s.effective_to||s.effective_to>=start));
 if(!monthSchedules.length)return null;
 if(monthSchedules.some(s=>s.schedule_type==='12x36'))return {special:true,rest:0,target:0,maxWork:0};
 if(monthSchedules.every(s=>['por_hora','variavel'].includes(s.schedule_type)))return null;
 let rest=0,work=0,consecutive=0,maxWork=0;
 const begin=new Date(start+'T12:00:00-03:00');begin.setDate(begin.getDate()-6);
 for(let i=0;i<days+6;i++){const dt=new Date(begin);dt.setDate(begin.getDate()+i);const d=dt.toISOString().slice(0,10);if(d<start) {if(expectedH(scheduleForH(employeeId,d),d,employeeId)||(sessions||[]).some(s=>s.employee_id===employeeId&&s.day===d&&s.actual>0))consecutive++;else consecutive=0;continue}
  if(expectedH(scheduleForH(employeeId,d),d,employeeId)||(sessions||[]).some(s=>s.employee_id===employeeId&&s.day===d&&s.actual>0)){work++;consecutive++;maxWork=Math.max(maxWork,consecutive)}else{rest++;consecutive=0}
 }
 return {special:false,rest,target:Math.ceil(days*2/7),maxWork,compliant:rest>=Math.ceil(days*2/7)&&maxWork<=6};
}
function sessionsH(){
 const sorted=[...dataH.punches].sort((a,b)=>new Date(a.punched_at)-new Date(b.punched_at));
 const open=new Map(),out=[];
 for(const p of sorted){
  let s=open.get(p.employee_id);
  if(p.punch_type==='entrada'){if(s)out.push({...s,open:true,invalid:true});open.set(p.employee_id,{employee_id:p.employee_id,start:p.punched_at,breaks:[],breakStart:null,marks:1});continue;}
  if(!s)continue;
  if(p.punch_type==='inicio_intervalo'){s.breakStart=p.punched_at;s.marks++;continue}
  if(p.punch_type==='fim_intervalo'&&s.breakStart){s.breaks.push([s.breakStart,p.punched_at]);s.breakStart=null;s.marks++;continue}
  if(p.punch_type==='saida'){
   s.end=p.punched_at;s.marks++;s.day=zonedPartsH(s.start).date;
   const elapsed=(new Date(s.end)-new Date(s.start))/60000,recorded=s.breaks.reduce((a,b)=>a+(new Date(b[1])-new Date(b[0]))/60000,0),sch=scheduleForH(p.employee_id,s.day);
   s.requiredBreak=elapsed>360?Number(sch?.break_minutes||dataH.rules?.break_minimum_minutes||60):elapsed>240?15:0;
   const confirmed=dataH.occurrences.find(o=>o.employee_id===p.employee_id&&o.occurrence_date===s.day&&['missing_break_start','missing_break_end'].includes(o.occurrence_type)&&o.status==='unjustified'&&Number(o.minutes)>0);
   s.breakTaken=recorded;s.breakUnverified=s.requiredBreak>0&&s.breaks.length===0;
   s.breakDeficit=s.breaks.length?Math.max(0,s.requiredBreak-recorded):Number(confirmed?.minutes||0);
   const effectiveBreak=s.breaks.length?recorded:(confirmed?Number(confirmed.minutes):s.requiredBreak);
   s.actual=Math.max(0,elapsed-effectiveBreak-(s.breaks.length?s.breakDeficit:0));
   s.open=false;out.push(s);open.delete(p.employee_id);
  }
 }
 for(const s of open.values()){s.day=zonedPartsH(s.start).date;s.open=true;s.actual=Math.max(0,(Date.now()-new Date(s.start))/60000-s.breaks.reduce((a,b)=>a+(new Date(b[1])-new Date(b[0]))/60000,0));out.push(s)}
 return out;
}
function workNightMinutesH(s){
 if(!s.end)return 0;
 const start=new Date(s.start).getTime(),end=new Date(s.end).getTime(),rules=dataH.rules||{},schedule=scheduleForH(s.employee_id,zonedPartsH(s.start).date),applyExtension=schedule?.schedule_type!=='12x36'&&rules.night_extension!==false;
 const breaks=[...s.breaks].map(([a,b])=>[new Date(a).getTime(),new Date(b).getTime()]).sort((a,b)=>a[0]-b[0]);
 const intervals=[];let cursor=start;
 for(const [a,b] of breaks){if(a>cursor)intervals.push([cursor,a]);cursor=Math.max(cursor,b)}
 if(end>cursor)intervals.push([cursor,end]);
 const startText=String(rules.night_start||'22:00'),endText=String(rules.night_end||'05:00');
 let total=0;
 for(const [a,b] of intervals){
  let day=zonedPartsH(a).date,stop=zonedPartsH(b).date;
  for(let guard=0;day<=stop&&guard<4;guard++){
   const nightStart=new Date(day+'T'+startText+':00-03:00').getTime();
   let nightEnd=new Date(day+'T'+endText+':00-03:00').getTime();
   if(nightEnd<=nightStart)nightEnd+=86400000;
   const overlap=Math.max(0,Math.min(b,nightEnd)-Math.max(a,nightStart));
   total+=overlap/60000;
   if(overlap>0&&applyExtension&&b>nightEnd){
    const nextNight=new Date(day+'T'+startText+':00-03:00').getTime()+86400000;
    total+=Math.max(0,Math.min(b,nextNight)-Math.max(a,nightEnd))/60000;
   }
   const next=new Date(day+'T12:00:00-03:00');next.setDate(next.getDate()+1);day=zonedPartsH(next).date;
  }
 }
 return total;
}
function bankLotsH(employeeId){
 const entries=dataH.bank.filter(b=>b.employee_id===employeeId).sort((a,b)=>String(a.effective_date).localeCompare(String(b.effective_date))||String(a.created_at).localeCompare(String(b.created_at)));
 const lots=[];
 for(const entry of entries){
  const amount=Number(entry.minutes)*Number(entry.multiplier||1);
  if(entry.entry_type==='credit'){lots.push({id:entry.id,remaining:amount,multiplier:Number(entry.multiplier||1),expires_on:entry.expires_on});continue}
  if(entry.entry_type==='expiry'&&entry.source_id){const lot=lots.find(x=>x.id===entry.source_id);if(lot)lot.remaining=Math.max(0,lot.remaining-amount);continue}
  let debit=amount;
  for(const lot of lots){if(debit<=0)break;const used=Math.min(lot.remaining,debit);lot.remaining-=used;debit-=used}
 }
 return lots;
}
function bankBalanceH(employeeId){return bankLotsH(employeeId).reduce((sum,lot)=>sum+lot.remaining,0)}
function summaryH(sessions=sessionsH()){
 const rules=dataH.rules||{},daily=new Map();
 for(const s of sessions){
  const key=s.employee_id+'|'+s.day,old=daily.get(key)||{employee_id:s.employee_id,day:s.day,actual:0,night:0,open:false,holiday:false,sunday:false,planned:0,late:0,early:0,breakTaken:0,breakDeficit:0};
  old.actual+=s.actual;old.night+=workNightMinutesH(s);old.open=old.open||s.open;old.breakTaken+=Number(s.breakTaken||0);old.breakDeficit+=Number(s.breakDeficit||0)
  const dt=new Date(s.day+'T12:00:00-03:00');old.sunday=dt.getDay()===0;
  old.holiday=dataH.holidays.some(h=>h.holiday_date===s.day&&h.is_paid!==false);
  const sch=scheduleForH(s.employee_id,s.day),dayException=dataH.scheduleExceptions.find(x=>x.employee_id===s.employee_id&&x.exception_date===s.day);
  if(dayException){old.planned=0;}
  else if(sch?.shift_start&&sch?.shift_end){
   const a=Number(sch.shift_start.slice(0,2))*60+Number(sch.shift_start.slice(3,5)),b=Number(sch.shift_end.slice(0,2))*60+Number(sch.shift_end.slice(3,5));
   const actualStart=zonedPartsH(s.start),actualEnd=s.end?zonedPartsH(s.end):null;
   const late=(actualStart.hour*60+actualStart.minute-a+1440)%1440,early=actualEnd?(b-(actualEnd.hour*60+actualEnd.minute)+1440)%1440:0;
   old.late+=late<=720?late:0;old.early+=early<=720?early:0;
   old.planned=Math.max(old.planned,((b-a+1440)%1440)-Number(sch.break_minutes||0));
  }else if(expectedH(sch,s.day,s.employee_id))old.planned=Number(sch?.weekly_hours||44)*60/(sch?.weekdays?.length||5);
  daily.set(key,old);
 }
 const rows=[...daily.values()].map(d=>{
  const emp=dataH.employees.find(e=>e.id===d.employee_id),comp=dataH.comp.find(x=>x.employee_id===d.employee_id)||{};
  const legalWeekly=statutoryWeeklyCapH(d.day)/60,contractWeekly=Number(comp.weekly_hours||rules.weekly_standard_minutes/60||legalWeekly),companyWeekly=Number(rules.weekly_standard_minutes||legalWeekly*60)/60,effectiveWeekly=Math.min(contractWeekly,legalWeekly,companyWeekly),divisor=Number(comp.monthly_hour_divisor||effectiveWeekly*5);
  const base=comp.remuneration_basis==='hourly'?Number(comp.hourly_rate||0):Number(comp.salary_base||0)/Math.max(1,divisor);
  const tolerance=Number(rules.daily_tolerance_minutes??10),dailyLimit=rules.overtime_daily_threshold_minutes==null?(d.planned>0?d.planned:null):Number(rules.overtime_daily_threshold_minutes);
  let overtime=dailyLimit==null?0:Math.max(0,d.actual-dailyLimit);if(overtime<=tolerance)overtime=0;
  const nightDivisor=rules.night_reduced_hour===false?60:Number(rules.night_hour_minutes||52.5);
  const daySchedule=scheduleForH(d.employee_id,d.day),dayException=dataH.scheduleExceptions.find(x=>x.employee_id===d.employee_id&&x.exception_date===d.day);
  const dayDate=new Date(d.day+'T12:00:00-03:00'),weekMonday=new Date(dayDate);weekMonday.setDate(dayDate.getDate()-((dayDate.getDay()+6)%7));
  const weekSunday=new Date(weekMonday);weekSunday.setDate(weekMonday.getDate()+6);
  const hasCompRest=dataH.scheduleExceptions.some(x=>x.employee_id===d.employee_id&&x.exception_type==='extra_rest'&&x.exception_date>d.day&&x.exception_date>=weekMonday.toISOString().slice(0,10)&&x.exception_date<=weekSunday.toISOString().slice(0,10));
  const scheduledSunday=baseExpectedH(daySchedule,d.day)&&dayException?.exception_type!=='extra_rest';
  const restDayWorked=dayException?.exception_type==='extra_work'&&!baseExpectedH(daySchedule,d.day);const specialDay=daySchedule?.schedule_type!=='12x36'&&(d.holiday||(d.sunday&&!scheduledSunday)||restDayWorked)&&!hasCompRest;
  return {...d,name:emp?.full_name||'Funcionário',base,overtime,nightHours:d.night/nightDivisor,overtimeNightMinutes:Math.min(overtime,d.night),specialDay};
 });
 const weeks=new Map();
 for(const row of rows){
  const dt=new Date(row.day+'T12:00:00-03:00'),weekStart=new Date(dt);
  weekStart.setDate(dt.getDate()-((dt.getDay()+6)%7));
  const key=row.employee_id+'|'+weekStart.toISOString().slice(0,10);
  const w=weeks.get(key)||{actual:0,dailyOt:0,items:[],weekStart};
  w.actual+=row.actual;w.dailyOt+=row.overtime;w.items.push(row);weeks.set(key,w);
 }
 for(const w of weeks.values()){
  if(w.items.some(row=>scheduleForH(row.employee_id,row.day)?.schedule_type==='12x36'))continue;
  const empComp=dataH.comp.find(x=>x.employee_id===w.items[0].employee_id)||{};
  const weekEnd=new Date(w.weekStart);weekEnd.setDate(weekEnd.getDate()+6);
  const cap=statutoryWeeklyCapH(weekEnd.toISOString().slice(0,10));
  const contractLimit=Number(empComp.weekly_hours||rules.weekly_standard_minutes/60||cap/60)*60;
  const companyLimit=Number(rules.weekly_standard_minutes||cap);
  const limit=Math.min(cap,contractLimit,companyLimit),extra=Math.max(0,w.actual-limit-w.dailyOt);
  if(extra>0){
   w.items.sort((a,b)=>b.day.localeCompare(a.day));
   let remaining=extra;
   for(const row of w.items){
    if(remaining<=0)break;
    const allocation=Math.min(remaining,Math.max(0,row.actual-row.overtime));
    if(allocation<=0)continue;
    const nightAllocation=Math.min(allocation,Math.max(0,row.night-row.overtimeNightMinutes));
    row.overtime+=allocation;row.overtimeNightMinutes+=nightAllocation;remaining-=allocation;
   }
  }
 }
 const nightPercent=Number(rules.night_additional_percent??20),specialMultiplier=Number(rules.sunday_holiday_multiplier||2),overtimeMultiplier=Number(rules.overtime_multiplier||1.5);
 for(const row of rows){
  const overtimeNight=Math.min(row.overtime,Number(row.overtimeNightMinutes||0)),overtimeDay=Math.max(0,row.overtime-overtimeNight);
  const regularNight=Math.max(0,row.night-overtimeNight),regularMinutes=Math.max(0,row.actual-row.overtime),payMultiplier=row.specialDay?specialMultiplier:overtimeMultiplier;
  row.nightHours=row.night/(rules.night_reduced_hour===false?60:Number(rules.night_hour_minutes||52.5));
  row.nightValue=regularNight/(rules.night_reduced_hour===false?60:Number(rules.night_hour_minutes||52.5))*row.base*nightPercent/100;
  row.overtimeValue=(overtimeDay/60+overtimeNight/(rules.night_reduced_hour===false?60:Number(rules.night_hour_minutes||52.5)))*row.base*payMultiplier;
  row.overtimeNightValue=overtimeNight/(rules.night_reduced_hour===false?60:Number(rules.night_hour_minutes||52.5))*row.base*nightPercent/100*payMultiplier;
  row.premium=row.specialDay?regularMinutes/60*row.base*(specialMultiplier-1):0;
  row.breakIndemnity=Number(row.breakDeficit||0)/60*row.base*1.5;
  row.estimatedAdditional=row.nightValue+row.premium+row.overtimeValue+row.overtimeNightValue+row.breakIndemnity;
 }
 return rows.filter(r=>r.day.slice(0,7)===monthPick);
}
async function loadH(){
 if(!companyId)throw Error('Selecione uma empresa.');
 const cid=encodeURIComponent(companyId);
 const monthStart=monthPick+'-01',monthEnd=new Date(Number(monthPick.slice(0,4)),Number(monthPick.slice(5,7)),0).toISOString().slice(0,10),nextMonth=new Date(Number(monthPick.slice(0,4)),Number(monthPick.slice(5,7)),1).toISOString().slice(0,10),fetchStart=new Date(monthStart+'T12:00:00-03:00');fetchStart.setDate(fetchStart.getDate()-7);const fetchEnd=new Date(nextMonth+'T12:00:00-03:00');fetchEnd.setDate(fetchEnd.getDate()+7);
 const [employees,schedules,punches,comp,rules,holidays,scheduleExceptions,occurrences,bank,periods]=await Promise.all([
  apiAllH('employees','select=id,full_name,email,status,employment_status&company_id=eq.'+cid+'&order=full_name.asc,id.asc'),
  apiAllH('hr_work_schedules','select=*&company_id=eq.'+cid+'&order=effective_from.desc,id.asc'),
  apiAllH('hr_time_punches','select=*&company_id=eq.'+cid+'&and=(punched_at.gte.'+fetchStart.toISOString()+',punched_at.lt.'+fetchEnd.toISOString()+')&order=punched_at.asc,id.asc'),
  apiAllH('employee_compensation','select=employee_id,salary_base,weekly_hours,remuneration_basis,hourly_rate,monthly_hour_divisor&company_id=eq.'+cid+'&order=employee_id.asc'),
  apiH('hr_time_rules','select=*&company_id=eq.'+cid+'&limit=1'),
  apiAllH('hr_holidays','select=*&company_id=eq.'+cid+'&holiday_date=gte.'+monthStart+'&holiday_date=lte.'+monthEnd+'&order=holiday_date.asc,id.asc'),
  apiAllH('hr_schedule_exceptions','select=*&company_id=eq.'+cid+'&exception_date=gte.'+fetchStart.toISOString().slice(0,10)+'&exception_date=lte.'+monthEnd+'&order=exception_date.asc,id.asc'),
  apiAllH('hr_time_occurrences','select=*&company_id=eq.'+cid+'&occurrence_date=gte.'+monthStart+'&occurrence_date=lte.'+monthEnd+'&order=occurrence_date.desc,id.desc'),
  apiAllH('hr_time_bank_entries','select=*&company_id=eq.'+cid+'&order=effective_date.asc,created_at.asc,id.asc'),
  apiAllH('hr_time_periods','select=*&company_id=eq.'+cid+'&period_month=eq.'+monthStart+'&order=employee_id.asc')
 ]);
 Object.assign(dataH,{employees,schedules,punches,comp,rules:rules[0]||null,holidays,scheduleExceptions,occurrences,bank,periods});
}
function renderH(){
 const host=$('view');if(!host)return;
 const attendanceSessions=sessionsH(),rows=summaryH(attendanceSessions),rules=dataH.rules||{},bankByEmp=new Map(),restRows=dataH.employees.map(e=>({employee:e,rest:restComplianceH(e.id,attendanceSessions)})).filter(x=>x.rest),monthCap=statutoryWeeklyCapH(monthPick+'-28')/60,specialSchedules=dataH.schedules.filter(s=>monthPick>='2026-12'&&['6x1','12x36'].includes(s.schedule_type)&&s.effective_from<=(monthPick+'-31')&&(!s.effective_to||s.effective_to>=(monthPick==='2026-12'?'2026-12-16':monthPick+'-01')));
 for(const b of dataH.bank){const delta=bankBalanceH(b.employee_id);bankByEmp.set(b.employee_id,delta)}
 const periodByEmp=new Map(dataH.periods.map(p=>[p.employee_id,p]));
 const total=rows.reduce((a,r)=>{a.minutes+=r.actual;a.ot+=r.overtime;a.extra+=r.estimatedAdditional;return a},{minutes:0,ot:0,extra:0});
 const monthStart=monthPick+'-01',lastDay=new Date(Number(monthPick.slice(0,4)),Number(monthPick.slice(5,7)),0).getDate();
 const missing=[],monthSessions=attendanceSessions;
 for(const e of dataH.employees.filter(x=>x.status!=='inactive'&&x.employment_status!=='inativo')){
  for(let day=1;day<=lastDay;day++){const d=monthPick+'-'+String(day).padStart(2,'0');if(d>todayH())continue;const sch=scheduleForH(e.id,d);if(!expectedH(sch,d,e.id))continue;
   const daySessions=monthSessions.filter(s=>s.employee_id===e.id&&s.day===d);
   const hasOcc=dataH.occurrences.some(o=>o.employee_id===e.id&&o.occurrence_date===d);
   if(!daySessions.length&&!hasOcc)missing.push({employee:e,date:d,kind:'absence'});
   else if(daySessions.some(s=>s.open)&&!hasOcc)missing.push({employee:e,date:d,kind:'missing_exit'});
   else if(daySessions.some(s=>!s.open&&(s.breakUnverified||s.breakDeficit>0))&&!hasOcc)missing.push({employee:e,date:d,kind:'missing_break_start',minutes:daySessions.reduce((n,s)=>n+Number(s.breakDeficit||0),0)||null});
  }
 }
 for(const e of dataH.employees){
  const completed=monthSessions.filter(s=>s.employee_id===e.id&&!s.open&&s.end).sort((a,b)=>new Date(a.start)-new Date(b.start));
  for(let n=1;n<completed.length;n++){
   const previous=completed[n-1],next=completed[n],gap=(new Date(next.start)-new Date(previous.end))/60000,sch=scheduleForH(e.id,previous.day)||scheduleForH(e.id,next.day),required=sch?.schedule_type==='12x36'?2160:660;
   if(next.day.slice(0,7)===monthPick&&gap>=0&&gap<required&&!dataH.occurrences.some(o=>o.employee_id===e.id&&o.occurrence_date===next.day&&o.occurrence_type==='interjornada_short'))missing.push({employee:e,date:next.day,kind:'interjornada_short',minutes:Math.round(required-gap)});
  }
 }
 host.innerHTML='<section class="gei-hr-panel"><div class="head"><div><h1>Apuração e fechamento de jornada</h1><span class="muted">Cálculo mensal, adicionais, ausências, banco de horas e conferência</span></div></div>'+
 '<div class="notice"><b>EC 141/2026:</b> limite semanal geral de '+monthCap+'h nesta competência; 42h a partir de 16/12/2026 e 40h a partir de 16/12/2027, sem redução salarial. Dois repousos semanais remunerados passam a valer em 16/12/2026. Escalas especiais exigem conferência do instrumento coletivo e das regras complementares.</div>'+(specialSchedules.length&&!rules.rest_schedule_agreement_reference?'<div class="notice"><b>Atenção às escalas especiais:</b> há registros 6x1/12x36 ativos neste período, mas nenhum instrumento coletivo foi informado nos parâmetros. Confira a adequação à EC 141/2026 e às normas específicas do MTE.</div>':'')+'<div class="notice"><b>Importante:</b> módulo de tratamento e apuração gerencial. O registro oficial REP-P exige requisitos próprios (incluindo sincronismo com Hora Legal Brasileira, armazenamento inviolável, comprovantes e assinatura ICP-Brasil). Não declare este aplicativo como REP-P ou folha homologada.</div>'+
 '<div class="toolbar"><label>Mês de apuração <input id="hrCalcMonth" type="month" value="'+monthPick+'"></label><button type="button" class="alt" id="hrCalcReload">Atualizar dados</button><button type="button" class="alt" id="hrCalcExport">Exportar CSV</button></div>'+
 '<div class="grid"><div class="card"><span class="muted">Horas apuradas</span><div class="metric">'+minsH(total.minutes)+'</div></div><div class="card"><span class="muted">Horas extras estimadas</span><div class="metric">'+minsH(total.ot)+'</div></div><div class="card"><span class="muted">Adicionais estimados</span><div class="metric">'+moneyH(total.extra)+'</div></div></div>'+
 '<section class="card"><h3>Parâmetros de cálculo da empresa</h3><form id="hrRulesForm"><div class="grid">'+
 '<div class="field"><label>Jornada semanal padrão (horas)</label><input name="weekly_standard_minutes" type="number" min="1" max="168" step=".5" value="'+Number(rules.weekly_standard_minutes||statutoryWeeklyCapH(monthPick+'-28'))/60+'"></div>'+
 '<div class="field"><label>Limite diário para hora extra (minutos; vazio = escala)</label><input name="overtime_daily_threshold_minutes" type="number" min="0" max="1440" value="'+(rules.overtime_daily_threshold_minutes??'')+'"></div>'+
 '<div class="field"><label>Adicional de hora extra (%)</label><input name="overtime_multiplier" type="number" min="100" max="500" step=".1" value="'+Number(rules.overtime_multiplier||1.5)*100+'"></div>'+
 '<div class="field"><label>Multiplicador domingo/feriado (%)</label><input name="sunday_holiday_multiplier" type="number" min="100" max="500" step=".1" value="'+Number(rules.sunday_holiday_multiplier||2)*100+'"></div>'+
 '<div class="field"><label>Prorrogação noturna após 5h (exceto 12x36)</label><select name="night_extension"><option value="true" '+(rules.night_extension===false?'':'selected')+'>Aplicar quando houver continuidade</option><option value="false" '+(rules.night_extension===false?'selected':'')+'>Não aplicar</option></select></div><div class="field"><label>Hora noturna reduzida</label><select name="night_reduced_hour"><option value="true" '+(rules.night_reduced_hour===false?'':'selected')+'>Sim — 52min30s (se aplicável)</option><option value="false" '+(rules.night_reduced_hour===false?'selected':'')+'>Não</option></select></div><div class="field"><label>Adicional noturno (%)</label><input name="night_additional_percent" type="number" min="0" max="200" value="'+Number(rules.night_additional_percent??20)+'"></div>'+
 '<div class="field"><label>Início período noturno</label><input name="night_start" type="time" value="'+(rules.night_start||'22:00')+'"></div>'+
 '<div class="field"><label>Fim período noturno</label><input name="night_end" type="time" value="'+(rules.night_end||'05:00')+'"></div>'+
 '<div class="field"><label>Duração hora noturna reduzida (minutos)</label><input name="night_hour_minutes" type="number" min="1" max="60" step=".001" value="'+Number(rules.night_hour_minutes||52.5)+'"></div>'+
 '<div class="field"><label>Tolerância diária (minutos)</label><input name="daily_tolerance_minutes" type="number" min="0" max="60" value="'+Number(rules.daily_tolerance_minutes??10)+'"></div>'+
 '<div class="field"><label>Banco de horas</label><select name="bank_enabled"><option value="false" '+(rules.bank_enabled?'':'selected')+'>Desativado</option><option value="true" '+(rules.bank_enabled?'selected':'')+'>Ativado</option></select></div>'+
 '<div class="field"><label>Instrumento do banco</label><select name="bank_agreement_type"><option value="none">Não configurado</option><option value="individual" '+(rules.bank_agreement_type==="individual"?"selected":"")+'>Acordo individual</option><option value="collective" '+(rules.bank_agreement_type==="collective"?"selected":"")+'>Acordo/convenção coletiva</option></select></div>'+
 '<div class="field"><label>Validade do saldo (meses)</label><input name="bank_validity_months" type="number" min="1" max="12" value="'+(rules.bank_validity_months||'')+'"></div><div class="field"><label>Multiplicador de crédito no banco</label><input name="bank_credit_multiplier" type="number" min="1" max="5" step=".1" value="'+Number(rules.bank_credit_multiplier||1)+'"></div>'+
 '<div class="field"><label>Referência do ACT/CCT para escala especial e repousos</label><input name="rest_schedule_agreement_reference" maxlength="500" value="'+escH(rules.rest_schedule_agreement_reference||'')+'" placeholder="Número de registro/validade do instrumento coletivo"></div><div class="field"><label>Intervalo mínimo configurado (minutos)</label><input name="break_minimum_minutes" type="number" min="0" max="720" value="'+Number(rules.break_minimum_minutes??60)+'"></div>'+
 '</div><div class="field"><label>Observações / referência de acordo coletivo</label><textarea name="notes" rows="2">'+escH(rules.notes||'')+'</textarea></div><button type="submit">Salvar parâmetros</button></form></section>'+
 '<section class="card"><h3>Divisor mensal do salário-hora</h3><p class="muted">O divisor automático acompanha a jornada semanal efetiva: por exemplo, 44h → 220; 42h → 210; 40h → 200. Se a convenção coletiva da categoria definir divisor próprio, registre a exceção por funcionário.</p><form id="hrDivisorForm"><div class="grid"><div class="field"><label>Funcionário</label><select id="hrDivisorEmployee" name="employee_id">'+dataH.employees.map(e=>'<option value="'+e.id+'">'+escH(e.full_name)+'</option>').join('')+'</select></div><div class="field"><label>Divisor mensal específico (vazio = automático)</label><input name="monthly_hour_divisor" type="number" min="1" max="400" step=".01" placeholder="Ex.: 210"></div></div><button type="submit">Salvar divisor</button></form></section><section class="card"><h3>Calendário de feriados</h3><form id="hrHolidayForm"><div class="grid"><div class="field"><label>Data</label><input type="date" name="holiday_date" required></div><div class="field"><label>Nome do feriado</label><input name="title" maxlength="120" required></div><div class="field"><label>Abrangência</label><select name="scope"><option value="national">Nacional</option><option value="state">Estadual</option><option value="municipal">Municipal</option><option value="company">Da empresa</option></select></div><div class="field"><label>UF</label><input name="state_code" maxlength="2"></div><div class="field"><label>Município</label><input name="city_name" maxlength="100"></div></div><button type="submit">Adicionar feriado</button></form><button type="button" class="alt" id="hrNationalHolidays">Cadastrar feriados nacionais fixos de '+monthPick.slice(0,4)+'</button><p class="muted">Feriados estaduais e municipais devem ser cadastrados separadamente. Carnaval e Corpus Christi dependem da legislação local.</p><div id="hrHolidayList">'+(dataH.holidays.map(h=>'<p>'+dateLabelH(h.holiday_date)+' — '+escH(h.title)+' ('+escH(h.scope)+') <button class="danger small" data-holiday-delete="'+h.id+'">Excluir</button></p>').join('')||'<p class="muted">Nenhum feriado cadastrado neste mês.</p>')+'</div></section>'+
 '<section class="card"><h3>Repousos semanais — EC 141/2026</h3><p class="muted">A partir de 16/12/2026, a regra geral prevê dois repousos semanais remunerados. Regimes compensatórios especiais precisam de ACT/CCT válido e ao menos um repouso em cada período máximo de sete dias. Cadastre folgas extras para refletir a escala real.</p><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Repousos no período</th><th>Meta média</th><th>Máximo de dias seguidos</th><th>Situação</th></tr></thead><tbody>'+restRows.map(x=>'<tr><td>'+escH(x.employee.full_name)+'</td><td>'+(x.rest.special?'Regime 12x36':x.rest.rest)+'</td><td>'+(x.rest.special?'ACT/CCT':x.rest.target)+'</td><td>'+(x.rest.special?'—':x.rest.maxWork)+'</td><td>'+(x.rest.special?'Revisão do regime especial':x.rest.compliant?'Dentro da escala cadastrada':'Ajustar folgas / conferir ACT-CCT')+'</td></tr>').join('')+'</tbody></table></div>'+(adminH()?'<form id="hrScheduleExceptionForm"><div class="grid"><div class="field"><label>Funcionário</label><select name="employee_id">'+dataH.employees.map(e=>'<option value="'+e.id+'">'+escH(e.full_name)+'</option>').join('')+'</select></div><div class="field"><label>Data</label><input type="date" name="exception_date" required value="'+todayH()+'"></div><div class="field"><label>Ajuste da escala</label><select name="exception_type"><option value="extra_rest">Folga extra</option><option value="extra_work">Trabalho em dia de folga</option></select></div><div class="field"><label>Motivo / referência</label><input name="reason" minlength="3" maxlength="500" required></div></div><button type="submit">Salvar ajuste de escala</button></form><div>'+(dataH.scheduleExceptions.filter(x=>x.exception_date.slice(0,7)===monthPick).map(x=>'<p>'+escH(dataH.employees.find(e=>e.id===x.employee_id)?.full_name||'Funcionário')+' — '+dateLabelH(x.exception_date)+' — '+escH(x.exception_type)+' <button class="danger small" data-schedule-exception-delete="'+x.id+'">Excluir</button></p>').join('')||'<p class="muted">Nenhum ajuste de escala neste período.</p>')+'</div>':'')+'</section>'+
 '<section class="card"><h3>Ausências e marcações pendentes</h3><p class="muted">O sistema compara a escala com as jornadas do mês. A ausência é um alerta para conferência, nunca um desconto automático. Trabalho em domingo/feriado depende de escala, repouso compensatório e convenção; valores são estimativas.</p><button type="button" id="hrGenerateMissing" class="alt">Gerar ocorrências pendentes da jornada ('+missing.length+')</button><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Data</th><th>Ocorrência</th><th>Status</th><th>Motivo</th><th>Ação</th></tr></thead><tbody>'+(dataH.occurrences.map(o=>'<tr><td>'+escH(dataH.employees.find(e=>e.id===o.employee_id)?.full_name||'Funcionário')+'</td><td>'+dateLabelH(o.occurrence_date)+'</td><td>'+escH(o.occurrence_type)+'</td><td>'+escH(o.status)+'</td><td>'+escH(o.reason)+'</td><td>'+(adminH()&&o.status==='pending'?'<button class="alt small" data-occ-review="'+o.id+'" data-status="justified">Justificar</button> <button class="danger small" data-occ-review="'+o.id+'" data-status="unjustified">Não justificada</button>':'—')+'</td></tr>').join('')||'<tr><td colspan="6">Nenhuma ocorrência registrada.</td></tr>')+'</tbody></table></div>'+
 (adminH()?'<form id="hrOccurrenceForm"><div class="grid"><div class="field"><label>Funcionário</label><select name="employee_id">'+dataH.employees.map(e=>'<option value="'+e.id+'">'+escH(e.full_name)+'</option>').join('')+'</select></div><div class="field"><label>Data</label><input type="date" name="occurrence_date" required value="'+todayH()+'"></div><div class="field"><label>Tipo</label><select name="occurrence_type"><option value="absence">Ausência</option><option value="missing_entry">Entrada não marcada</option><option value="missing_exit">Saída não marcada</option><option value="justified_absence">Falta justificada</option><option value="medical_leave">Afastamento</option><option value="vacation">Férias</option><option value="day_off_worked">Folga trabalhada</option><option value="other">Outra ocorrência</option></select></div><div class="field"><label>Minutos</label><input type="number" name="minutes" min="0" max="1440"></div><div class="field"><label>Motivo (sem CID ou diagnóstico)</label><input name="reason" minlength="3" maxlength="1000" required></div></div><button type="submit">Registrar ocorrência</button></form>':'')+'</section>'+
 '<section class="card"><h3>Banco de horas</h3><p class="muted">Saldo abaixo é a soma dos lançamentos. O crédito automático não é criado sem validar o instrumento aplicável.</p><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Saldo</th><th>Últimos lançamentos</th></tr></thead><tbody>'+dataH.employees.map(e=>{const bs=dataH.bank.filter(b=>b.employee_id===e.id),balance=bankBalanceH(e.id);return '<tr><td>'+escH(e.full_name)+'</td><td>'+minsH(balance)+'</td><td>'+bs.slice(0,2).map(b=>escH(b.entry_type)+' '+minsH(b.minutes)).join(' · ')+'</td></tr>'}).join('')+'</tbody></table></div>'+
 (adminH()?'<button type="button" class="alt" id="hrExpireBank">Processar créditos vencidos</button><form id="hrBankForm"><div class="grid"><div class="field"><label>Funcionário</label><select name="employee_id">'+dataH.employees.map(e=>'<option value="'+e.id+'">'+escH(e.full_name)+'</option>').join('')+'</select></div><div class="field"><label>Movimento</label><select name="entry_type"><option value="credit">Crédito</option><option value="debit">Débito</option><option value="payout">Pagamento em folha</option><option value="adjustment">Ajuste</option></select></div><div class="field"><label>Minutos</label><input type="number" name="minutes" min="1" max="10080" required></div><div class="field"><label>Origem</label><select name="source_type"><option value="manual">Manual</option><option value="overtime">Hora extra</option><option value="compensation">Compensação</option><option value="absence">Ausência</option><option value="payroll">Folha</option></select></div><div class="field"><label>Data</label><input type="date" name="effective_date" required value="'+todayH()+'"></div><div class="field"><label>Vencimento do crédito</label><input type="date" name="expires_on"></div><div class="field"><label>Descrição / justificativa</label><input name="description" minlength="3" maxlength="500" required></div></div><button type="submit">Lançar movimento</button></form>':'')+'</section>'+
 '<section class="card"><h3>Apuração por funcionário</h3><div class="tablewrap"><table><thead><tr><th>Funcionário</th><th>Horas</th><th>Extras</th><th>Atrasos</th><th>Saídas antecipadas</th><th>Noturnas</th><th>Horas em domingo/feriado</th><th>Valor de extras</th><th>Adic. noturno</th><th>Adic. domingo/feriado</th><th>Intervalo suprimido</th><th>Indenização de intervalo</th><th>Total estimado</th><th>Fechamento</th></tr></thead><tbody>'+dataH.employees.map(e=>{const r=rows.filter(x=>x.employee_id===e.id),actual=r.reduce((a,x)=>a+x.actual,0),ot=r.reduce((a,x)=>a+x.overtime,0),late=r.reduce((a,x)=>a+x.late,0),early=r.reduce((a,x)=>a+x.early,0),night=r.reduce((a,x)=>a+x.nightHours,0),specialHours=r.filter(x=>x.specialDay).reduce((a,x)=>a+x.actual,0),otValue=r.reduce((a,x)=>a+x.overtimeValue+x.overtimeNightValue,0),nightValue=r.reduce((a,x)=>a+x.nightValue,0),premiumValue=r.reduce((a,x)=>a+x.premium,0),breakDeficit=r.reduce((a,x)=>a+x.breakDeficit,0),breakValue=r.reduce((a,x)=>a+x.breakIndemnity,0),extra=r.reduce((a,x)=>a+x.estimatedAdditional,0),period=periodByEmp.get(e.id);return '<tr><td>'+escH(e.full_name)+'</td><td>'+minsH(actual)+'</td><td>'+minsH(ot)+'</td><td>'+minsH(late)+'</td><td>'+minsH(early)+'</td><td>'+night.toFixed(2).replace('.',',')+' h</td><td>'+minsH(specialHours)+'</td><td>'+moneyH(otValue)+'</td><td>'+moneyH(nightValue)+'</td><td>'+moneyH(premiumValue)+'</td><td>'+minsH(breakDeficit)+'</td><td>'+moneyH(breakValue)+'</td><td>'+moneyH(extra)+'</td><td>'+(period?.status||'Aberto')+'</td></tr>'}).join('')+'</tbody></table></div>'+
 (adminH()?'<button type="button" id="hrCloseMonth">Fechar competência para todos</button> <button type="button" class="alt" id="hrReopenMonth">Reabrir competência (com justificativa)</button>':'')+'</section></section>';
 $('hrCalcMonth').onchange=async e=>{monthPick=e.target.value;await reloadH()};
 $('hrCalcReload').onclick=reloadH;
 $('hrCalcExport').onclick=()=>{const rowsCsv=[['Funcionário','Data','Minutos trabalhados','Minutos extras','Atraso (min)','Saída antecipada (min)','Horas noturnas','Valor horas extras','Adicional noturno','Adicional domingo/feriado','Intervalo suprimido (min)','Indenização intervalo','Total estimado'],...rows.map(r=>[r.name,r.day,r.actual,r.overtime,r.late,r.early,r.nightHours.toFixed(2),(r.overtimeValue+r.overtimeNightValue).toFixed(2),r.nightValue.toFixed(2),r.premium.toFixed(2),r.breakDeficit,r.breakIndemnity.toFixed(2),r.estimatedAdditional.toFixed(2)])];const csv='\uFEFF'+rowsCsv.map(r=>r.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(';')).join('\r\n');const a=document.createElement('a'),u=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));a.href=u;a.download='gei360-apuracao-'+monthPick+'.csv';a.click();URL.revokeObjectURL(u)};
 $('hrRulesForm').onsubmit=async e=>{e.preventDefault();const f=new FormData(e.target),v=Object.fromEntries(f.entries()),payload={company_id:companyId,weekly_standard_minutes:Math.round(Number(v.weekly_standard_minutes)*60),overtime_daily_threshold_minutes:v.overtime_daily_threshold_minutes===''?null:Number(v.overtime_daily_threshold_minutes),overtime_multiplier:Number(v.overtime_multiplier)/100,sunday_holiday_multiplier:Number(v.sunday_holiday_multiplier)/100,night_additional_percent:Number(v.night_additional_percent),night_start:v.night_start,night_end:v.night_end,night_hour_minutes:Number(v.night_hour_minutes),night_reduced_hour:v.night_reduced_hour==='true',night_extension:v.night_extension==='true',daily_tolerance_minutes:Number(v.daily_tolerance_minutes),bank_enabled:v.bank_enabled==='true',bank_agreement_type:v.bank_agreement_type,bank_validity_months:v.bank_validity_months===''?null:Number(v.bank_validity_months),bank_credit_multiplier:Number(v.bank_credit_multiplier||1),break_minimum_minutes:Number(v.break_minimum_minutes),notes:v.notes||null,rest_schedule_agreement_reference:v.rest_schedule_agreement_reference||null,created_by:session.user.id,updated_at:new Date().toISOString()};if(payload.bank_agreement_type==='none')payload.bank_validity_months=null;if(payload.bank_enabled&&payload.bank_agreement_type==='none'){alert('Para ativar o banco de horas, selecione o acordo individual ou coletivo aplicável.');return}if(payload.bank_enabled&&!payload.bank_validity_months){alert('Informe a validade do banco de horas conforme o acordo.');return}if(payload.bank_agreement_type==='individual'&&payload.bank_validity_months>6){alert('A validade do acordo individual escrito não pode ultrapassar 6 meses.');return}if(payload.bank_agreement_type==='collective'&&payload.bank_validity_months>12){alert('A validade do acordo/convenção coletiva não pode ultrapassar 12 meses.');return}try{await api('/rest/v1/hr_time_rules?on_conflict=company_id',{method:'POST',body:payload,headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});alert('Parâmetros salvos.');await reloadH()}catch(err){alert('Falha ao salvar parâmetros: '+err.message)}};
 $('hrNationalHolidays')?.addEventListener('click',async()=>{const year=Number(monthPick.slice(0,4)),dates=[['01-01','Confraternização Universal'],['04-21','Tiradentes'],['05-01','Dia Mundial do Trabalho'],['09-07','Independência do Brasil'],['10-12','Nossa Senhora Aparecida'],['11-02','Finados'],['11-15','Proclamação da República'],['11-20','Dia Nacional de Zumbi e da Consciência Negra'],['12-25','Natal']];if(!confirm('Cadastrar os feriados nacionais fixos de '+year+'? Os registros existentes serão preservados.'))return;try{await api('/rest/v1/hr_holidays?on_conflict=company_id,holiday_date,title',{method:'POST',body:dates.map(([md,title])=>({company_id:companyId,holiday_date:year+'-'+md,title,scope:'national',is_paid:true,created_by:session.user.id})),headers:{Prefer:'resolution=ignore-duplicates,return=minimal'}});await reloadH()}catch(err){alert('Falha ao cadastrar feriados nacionais: '+err.message)}});
 $('hrDivisorEmployee').onchange=()=>{const row=dataH.comp.find(x=>x.employee_id===$('hrDivisorEmployee').value);$('hrDivisorForm').elements.monthly_hour_divisor.value=row?.monthly_hour_divisor??''};$('hrDivisorForm').onsubmit=async e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target).entries()),current=dataH.comp.find(x=>x.employee_id===v.employee_id);if(!current){alert('Cadastre primeiro a remuneração do funcionário na ficha de RH.');return}const cap=statutoryWeeklyCapH(monthPick+'-28')/60,contract=Number(current.weekly_hours||rules.weekly_standard_minutes/60||cap),company=Number(rules.weekly_standard_minutes||cap*60)/60,automatic=Math.min(cap,contract,company)*5,chosen=v.monthly_hour_divisor===''?null:Number(v.monthly_hour_divisor);if(chosen&&chosen>automatic){alert('O divisor informado não pode ser maior que o divisor automático da jornada efetiva ('+automatic+').');return}const payload={company_id:companyId,employee_id:v.employee_id,salary_base:current.salary_base,weekly_hours:current.weekly_hours,remuneration_basis:current.remuneration_basis,hourly_rate:current.hourly_rate,monthly_hour_divisor:chosen,created_by:session.user.id};try{await api('/rest/v1/employee_compensation?on_conflict=company_id,employee_id',{method:'POST',body:payload,headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});await reloadH()}catch(err){alert('Falha ao salvar divisor: '+err.message)}};
 $('hrHolidayForm').onsubmit=async e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target).entries());try{await api('/rest/v1/hr_holidays',{method:'POST',body:{...v,company_id:companyId,created_by:session.user.id,is_paid:true}});await reloadH()}catch(err){alert('Falha ao cadastrar feriado: '+err.message)}};
 $('hrScheduleExceptionForm')?.addEventListener('submit',async e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target).entries());try{await api('/rest/v1/hr_schedule_exceptions?on_conflict=company_id,employee_id,exception_date',{method:'POST',body:{...v,company_id:companyId,created_by:session.user.id},headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});await reloadH()}catch(err){alert('Falha ao salvar ajuste de escala: '+err.message)}});host.querySelectorAll('[data-schedule-exception-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Excluir este ajuste de escala?'))return;try{await api('/rest/v1/hr_schedule_exceptions?id=eq.'+b.dataset.scheduleExceptionDelete,{method:'DELETE'});await reloadH()}catch(err){alert('Não foi possível excluir: '+err.message)}});
 $('hrOccurrenceForm')?.addEventListener('submit',async e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target).entries());try{await api('/rest/v1/hr_time_occurrences',{method:'POST',body:{...v,company_id:companyId,minutes:v.minutes===''?null:Number(v.minutes),requested_by:session.user.id,status:'pending'}});await reloadH()}catch(err){alert('Falha ao registrar ocorrência: '+err.message)}});
 $('hrExpireBank')?.addEventListener('click',async()=>{const expired=dataH.employees.flatMap(e=>bankLotsH(e.id).filter(l=>l.expires_on&&l.expires_on<=todayH()&&l.remaining>0).map(l=>({...l,employee_id:e.id})));if(!expired.length){alert('Nenhum crédito vencido para processar.');return}if(!confirm('Registrar expiração de '+expired.length+' crédito(s) vencido(s)?'))return;try{for(const credit of expired){const prior=await api('/rest/v1/hr_time_bank_entries?select=id&company_id=eq.'+companyId+'&employee_id=eq.'+credit.employee_id+'&source_type=eq.expiry&source_id=eq.'+credit.id+'&limit=1');if(!prior.length)await api('/rest/v1/hr_time_bank_entries',{method:'POST',body:{company_id:companyId,employee_id:credit.employee_id,effective_date:todayH(),entry_type:'expiry',minutes:Math.max(1,Math.ceil(credit.remaining/Number(credit.multiplier||1))),source_type:'expiry',source_id:credit.id,multiplier:credit.multiplier||1,description:'Expiração do crédito de banco de horas '+credit.id,approved_by:session.user.id}})}await reloadH();alert('Expirações registradas.')}catch(err){alert('Falha ao processar vencimentos: '+err.message)}});
 $('hrBankForm')?.addEventListener('submit',async e=>{e.preventDefault();const v=Object.fromEntries(new FormData(e.target).entries());if(v.entry_type!=='credit'&&Number(v.minutes)>bankBalanceH(v.employee_id)){alert('O débito é maior que o saldo disponível do funcionário.');return}try{await api('/rest/v1/hr_time_bank_entries',{method:'POST',body:{...v,company_id:companyId,minutes:Number(v.minutes),approved_by:session.user.id}});await reloadH()}catch(err){alert('Falha ao lançar banco: '+err.message)}});
 $('hrGenerateMissing').onclick=async()=>{if(!missing.length){alert('Nenhuma ausência de marcação foi identificada pela escala neste mês.');return}if(!confirm('Criar '+missing.length+' ocorrências pendentes para conferência? Nenhum desconto será aplicado.'))return;try{for(const m of missing){await api('/rest/v1/hr_time_occurrences',{method:'POST',body:{company_id:companyId,employee_id:m.employee.id,occurrence_date:m.date,occurrence_type:m.kind,status:'pending',minutes:m.minutes||null,reason:m.kind==='absence'?'Sem marcação localizada na escala. Conferir falta, folga, atestado ou falha de registro.':m.kind==='missing_exit'?'Jornada iniciada sem marcação de saída. Conferir o horário real e solicitar tratamento.':m.kind==='interjornada_short'?'Intervalo entre jornadas inferior a 11 horas (ou 36 horas no 12x36). Conferir regime e instrumento coletivo.':'Intervalo sem marcação ou abaixo do mínimo configurado. Conferir o intervalo realmente realizado.',requested_by:session.user.id}})}await reloadH()}catch(err){alert('Algumas ocorrências podem ter sido criadas antes da falha. Atualize para conferir. '+err.message)}};
 host.querySelectorAll('[data-holiday-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Excluir este feriado do calendário da empresa?'))return;try{await api('/rest/v1/hr_holidays?id=eq.'+b.dataset.holidayDelete,{method:'DELETE'});await reloadH()}catch(e){alert(e.message)}});
 host.querySelectorAll('[data-occ-review]').forEach(b=>b.onclick=async()=>{const note=prompt('Observação da revisão (obrigatória):');if(!note||note.trim().length<3)return;const occurrence=dataH.occurrences.find(o=>o.id===b.dataset.occReview);let minutes=occurrence?.minutes??null;if(b.dataset.status==='unjustified'&&['missing_break_start','missing_break_end'].includes(occurrence?.occurrence_type)){const entered=prompt('Quantos minutos de intervalo foram efetivamente suprimidos?');minutes=Number(entered);if(!Number.isFinite(minutes)||minutes<=0||minutes>720){alert('Informe os minutos suprimidos para concluir a revisão.');return}}try{await api('/rest/v1/hr_time_occurrences?id=eq.'+b.dataset.occReview,{method:'PATCH',body:{status:b.dataset.status,minutes,manager_note:note,reviewed_by:session.user.id,reviewed_at:new Date().toISOString(),updated_at:new Date().toISOString()}});await reloadH()}catch(e){alert(e.message)}});
 $('hrCloseMonth')?.addEventListener('click',async()=>{if(!confirm('Fechar a competência '+monthPick+' para todos os funcionários? O sistema salvará um resumo e bloqueará novas alterações no fechamento até reabertura.'))return;try{for(const e of dataH.employees){const r=rows.filter(x=>x.employee_id===e.id);const snap={month:monthPick,employee_id:e.id,minutes_worked:r.reduce((a,x)=>a+x.actual,0),overtime_minutes:r.reduce((a,x)=>a+x.overtime,0),late_minutes:r.reduce((a,x)=>a+x.late,0),early_departure_minutes:r.reduce((a,x)=>a+x.early,0),night_hours:r.reduce((a,x)=>a+x.nightHours,0),estimated_additional:r.reduce((a,x)=>a+x.estimatedAdditional,0),overtime_value:r.reduce((a,x)=>a+x.overtimeValue+x.overtimeNightValue,0),night_additional:r.reduce((a,x)=>a+x.nightValue,0),holiday_sunday_additional:r.reduce((a,x)=>a+x.premium,0),break_deficit_minutes:r.reduce((a,x)=>a+x.breakDeficit,0),break_indemnity:r.reduce((a,x)=>a+x.breakIndemnity,0),occurrence_ids:dataH.occurrences.filter(o=>o.employee_id===e.id).map(o=>o.id),closed_at:new Date().toISOString()};await api('/rest/v1/hr_time_periods?on_conflict=company_id,employee_id,period_month',{method:'POST',body:{company_id:companyId,employee_id:e.id,period_month:monthPick+'-01',status:'closed',summary:snap,closed_by:session.user.id,closed_at:new Date().toISOString(),updated_at:new Date().toISOString()},headers:{Prefer:'resolution=merge-duplicates,return=minimal'}});if(rules.bank_enabled&&rules.bank_agreement_type!=='none'){const ot=snap.overtime_minutes;if(ot>0){const period=await api('/rest/v1/hr_time_periods?select=id&company_id=eq.'+companyId+'&employee_id=eq.'+e.id+'&period_month=eq.'+monthPick+'-01&limit=1');if(period[0]){const exists=await api('/rest/v1/hr_time_bank_entries?select=id&company_id=eq.'+companyId+'&employee_id=eq.'+e.id+'&source_type=eq.overtime&source_id=eq.'+period[0].id+'&limit=1');if(!exists.length)await api('/rest/v1/hr_time_bank_entries',{method:'POST',body:{company_id:companyId,employee_id:e.id,effective_date:monthPick+'-01',entry_type:'credit',minutes:ot,source_type:'overtime',source_id:period[0].id,multiplier:Number(rules.bank_credit_multiplier||1),expires_on:rules.bank_validity_months?(()=>{const x=new Date(monthPick+'-01T12:00:00-03:00');x.setMonth(x.getMonth()+Number(rules.bank_validity_months));return x.toISOString().slice(0,10)})():null,description:'Crédito de horas extras apuradas na competência '+monthPick,approved_by:session.user.id}})}}}}await reloadH();alert('Competência fechada.')}catch(err){alert('Fechamento parcial; atualize para conferir. '+err.message)}});
 $('hrReopenMonth')?.addEventListener('click',async()=>{const reason=prompt('Informe o motivo da reabertura da competência:');if(!reason||reason.trim().length<5)return;try{for(const p of dataH.periods){await api('/rest/v1/hr_time_periods?id=eq.'+p.id,{method:'PATCH',body:{status:'reopened',reopened_by:session.user.id,reopened_at:new Date().toISOString(),reopen_reason:reason,updated_at:new Date().toISOString()}})}await reloadH()}catch(err){alert('Não foi possível reabrir: '+err.message)}});
}
async function reloadH(){try{await loadH();renderH()}catch(e){$('view').innerHTML='<div class="err">Não foi possível carregar a apuração: '+escH(e.message)+'</div>'}}
async function openH(){if(!adminH()){$('view').innerHTML='<div class="notice">A apuração, remuneração e fechamento são restritos a proprietário e administrador.</div>';return}await reloadH()}
window.setPage=function(page){if(page==='timepayroll'){document.querySelectorAll('[data-page]').forEach(b=>b.classList.toggle('active',b.dataset.page===page));$('pageTitle').textContent='Apuração de jornada';openH();return}return baseSetPage(page)};

})();
