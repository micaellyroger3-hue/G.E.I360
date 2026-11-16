/* G.E.I360 | Perfis empresariais e canais de venda
 * O perfil recomenda módulos; não finge conectar serviços externos.
 * Segredos e tokens de integrações nunca são armazenados no navegador.
 */
(function(){
'use strict';
const TYPES=[
 ['restaurant','Alimentação preparada (restaurante, lanchonete, padaria, pizzaria, cafeteria)'],
 ['grocery','Mercado e alimentos (mercadinho, supermercado, mercearia, açougue, hortifruti)'],
 ['retail','Loja / comércio em geral'],
 ['services','Prestação de serviços'],
 ['distributor','Distribuidora / atacado'],
 ['ecommerce','E-commerce / loja virtual'],
 ['construction','Construção / obras'],
 ['other','Outro ramo (qualquer atividade)']
];
const CHANNELS=[
 ['ifood','iFood'],
 ['whatsapp','WhatsApp'],
 ['instagram','Instagram'],
 ['physical_store','Loja física'],
 ['own_delivery','Entrega própria'],
 ['ecommerce','Loja virtual'],
 ['marketplace','Outros marketplaces']
];
const ROUTES={
 'Produtos e cardápio':'products','Produtos e códigos de barras':'products','Catálogo e preços':'products',
 'Catálogo e tabela de preços':'products','Estoque':'products','Estoque (se aplicável)':'products',
 'Estoque de produtos e insumos':'products','Materiais e estoque':'products',
 'Vendas':'sales','Vendas e caixa':'sales','Vendas e pedidos':'sales','Vendas e serviços':'sales',
 'Compras':'purchases','Compras e fornecedores':'purchases',
 'Clientes':'customers','Fornecedores':'suppliers',
 'Financeiro':'finance','Financeiro e relatórios':'finance',
 'Documentos e relatórios':'documents','Contratos e documentos':'documents','Relatórios':'reports',
 'Equipe (cadastros)':'employees',
 'Produção e fichas de preparo (registro manual)':'sector',
 'Controle manual de validade e perdas':'sector','Ordens de serviço (registro manual)':'sector',
 'Expedição (registro manual)':'sector','Separação e expedição (registro manual)':'sector',
 'Diário de obra (registro manual)':'sector'
};
const MODULES={
 restaurant:['Produtos e cardápio','Estoque de produtos e insumos','Produção e fichas de preparo (registro manual)','Vendas e pedidos','Compras e fornecedores','Clientes','Fornecedores','Financeiro','Entregas e integração de pedidos','Documentos e relatórios'],
 grocery:['Produtos e códigos de barras','Estoque','Controle manual de validade e perdas','Compras e fornecedores','Vendas e caixa','Clientes','Fornecedores','Financeiro','Documentos e relatórios'],
 retail:['Catálogo e preços','Estoque','Vendas e caixa','Compras e fornecedores','Clientes','Fornecedores','Financeiro','Documentos e relatórios'],
 services:['Ordens de serviço (registro manual)','Catálogo de serviços','Agenda de atendimento','Equipe (cadastros)','Clientes','Financeiro','Documentos e relatórios'],
 distributor:['Catálogo e tabela de preços','Estoque','Compras e fornecedores','Vendas e pedidos','Clientes','Fornecedores','Expedição (registro manual)','Multiestoque e logística avançada','Financeiro','Relatórios'],
 ecommerce:['Catálogo e preços','Estoque','Vendas e pedidos','Clientes','Separação e expedição (registro manual)','Integração com marketplaces','Financeiro','Relatórios'],
 construction:['Materiais e estoque','Compras e fornecedores','Equipe (cadastros)','Diário de obra (registro manual)','Clientes','Contratos e documentos','Financeiro','Relatórios'],
 other:['Clientes','Fornecedores','Estoque (se aplicável)','Vendas e serviços','Compras','Financeiro','Documentos e relatórios']
};
const $id=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let currentProfile=null;
function selectedChannels(){return CHANNELS.filter(([key])=>$id('gei_channel_'+key)?.checked).map(([key])=>key)}
function profileMarkup(){
 const typeOptions='<option value="">Selecione o ramo...</option>'+TYPES.map(([v,l])=>'<option value="'+v+'">'+l+'</option>').join('');
 const channelOptions=CHANNELS.map(([v,l])=>'<label style="display:flex;gap:8px;align-items:center;border:1px solid #e5eaf1;border-radius:8px;padding:9px;font-size:12px"><input type="checkbox" id="gei_channel_'+v+'" value="'+v+'"> '+l+'</label>').join('');
 return '<section class="card" id="geiBusinessProfile"><h3 style="margin:0 0 6px">Perfil inteligente da empresa</h3><p class="muted" style="margin:0 0 12px">Escolha o ramo e os canais utilizados. O G.E.I360 organiza os módulos recomendados para esse negócio.</p><p class="muted" style="font-size:11px;margin:0 0 12px">O núcleo de cadastros, estoque, vendas, compras, financeiro e documentos atende diferentes atividades. Se o ramo não estiver listado, escolha “Outro ramo”. Recursos específicos e integrações ainda não disponíveis aparecem como planejados.</p><div id="geiProfileCompleteness" class="notice">Cadastro incompleto: escolha o ramo e pelo menos um canal.</div><div class="field"><label for="geiBusinessType">Ramo de atividade</label><select id="geiBusinessType">'+typeOptions+'</select></div><div class="field"><label for="geiActivityDetail">Atividade específica (opcional)</label><input id="geiActivityDetail" maxlength="120" placeholder="Ex.: lanchonete, padaria, açougue, hortifruti, cafeteria..."></div><div class="field"><label>Canais de venda e atendimento</label><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:7px">'+channelOptions+'</div></div><div id="geiProfilePreview" class="notice" style="margin-top:12px">Selecione o ramo para visualizar os módulos recomendados.</div><div id="geiIfodPanel" class="notice hidden"></div><p id="geiProfileStatus" class="muted" style="font-size:11px;margin:8px 0 0">O perfil será salvo junto com os dados da empresa.</p></section>';
}
function updatePreview(){
 const type=$id('geiBusinessType')?.value||'';
 const channels=selectedChannels();
 const modules=MODULES[type]||MODULES.other;
 const complete=!!($id('companyName')?.value.trim()&&type&&channels.length);
 const completeness=$id('geiProfileCompleteness');
 if(completeness){
  completeness.className=complete?'ok':'notice';
  completeness.textContent=complete?'Cadastro completo: empresa, ramo e pelo menos um canal foram informados.':'Cadastro incompleto: informe o nome da empresa, escolha o ramo e marque ao menos um canal.';
 }
 const preview=$id('geiProfilePreview');
 if(preview){preview.innerHTML='<b>Módulos recomendados:</b><div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:8px">'+modules.map(x=>ROUTES[x]?'<button type="button" class="alt small" data-gei-page="'+ROUTES[x]+'">'+esc(x)+'</button>':'<span style="background:#f1f5f9;color:#64748b;border-radius:7px;padding:6px 8px;font-size:11px">'+esc(x)+' · planejado</span>').join('')+'</div><p style="font-size:10px;color:#718096;margin:9px 0 0">Botões abrem módulos disponíveis. Itens marcados como planejado ainda precisam ser desenvolvidos.</p>';preview.querySelectorAll('[data-gei-page]').forEach(button=>button.addEventListener('click',()=>setPage(button.dataset.geiPage)));}
 const ifood=$id('geiIfodPanel');
 if(ifood){
  const active=channels.includes('ifood');
  ifood.classList.toggle('hidden',!active);
  if(active)ifood.innerHTML='<b>Canal iFood selecionado</b><p style="margin:6px 0 0">O módulo de gestão do canal ficará identificado no perfil. A conexão para importar pedidos e sincronizar cardápio ainda depende de credenciais e liberação oficial do iFood, além de um serviço seguro no servidor. Nenhuma senha ou token deve ser colocado aqui.</p><span style="display:inline-block;margin-top:8px;font-weight:800">Status: aguardando integração oficial</span>';
 }
}
async function loadProfile(){
 currentProfile=null;
 if(!companyId)return;
 try{
  const rows=await api('/rest/v1/company_business_profiles?select=company_id,business_type,business_activity_detail,sales_channels,created_by,updated_at&company_id=eq.'+encodeURIComponent(companyId)+'&limit=1');
  currentProfile=rows?.[0]||null;
 }catch(e){
  const status=$id('geiProfileStatus');
  if(status)status.textContent='Perfil ainda não disponível no banco. Aplique a migração de perfil empresarial para ativar o salvamento.';
 }
}
async function saveProfile(){
 const status=$id('geiProfileStatus');
 if(!companyId)throw Error('Salve primeiro os dados da empresa.');
 if(!session?.user?.id)throw Error('Sessão inválida. Entre novamente.');
 const businessType=$id('geiBusinessType')?.value||'';
 const channels=selectedChannels();
 if(!businessType||!channels.length){if(status)status.textContent='Empresa salva. Perfil incompleto: escolha o ramo e marque pelo menos um canal.';return}
 const activityDetail=$id('geiActivityDetail')?.value.trim()||null;
 const payload={company_id:companyId,business_type:businessType,business_activity_detail:activityDetail,sales_channels:channels};
 try{
  if(currentProfile){
   await api('/rest/v1/company_business_profiles?company_id=eq.'+encodeURIComponent(companyId),{method:'PATCH',body:{business_type:payload.business_type,business_activity_detail:payload.business_activity_detail,sales_channels:payload.sales_channels}});
  }else{
   await api('/rest/v1/company_business_profiles',{method:'POST',body:{...payload,created_by:session.user.id}});
  }
  currentProfile={...payload,created_by:currentProfile?.created_by||session.user.id};
  if(status)status.textContent='Perfil empresarial salvo com sucesso.';
 }catch(error){
  if(status)status.textContent='Empresa salva. Perfil inteligente aguardando a migração e as permissões no Supabase: '+error.message;
 }
}
function attachProfile(){
 const form=$id('companyForm');
 if(!form||!$id('geiBusinessProfile'))return;
 const type=$id('geiBusinessType');
 type.value=currentProfile?.business_type||'';
 const activity=$id('geiActivityDetail');if(activity)activity.value=currentProfile?.business_activity_detail||'';
 for(const [key] of CHANNELS){const el=$id('gei_channel_'+key);if(el)el.checked=(currentProfile?.sales_channels||[]).includes(key)}
 type.onchange=updatePreview;
 const companyName=$id('companyName');if(companyName)companyName.addEventListener('input',updatePreview);
 for(const [key] of CHANNELS){const el=$id('gei_channel_'+key);if(el)el.onchange=updatePreview}
 updatePreview();
}
const originalRenderCompany=renderCompany;
if(typeof originalRenderCompany==='function'){
 renderCompany=function(){
  originalRenderCompany();
  const form=$id('companyForm');
  if(form&&!$id('geiBusinessProfile')){
   const button=form.querySelector('button[type="submit"],button:not([type])');
   if(button)button.insertAdjacentHTML('beforebegin',profileMarkup());
   loadProfile().then(attachProfile);
  }else attachProfile();
 };
}
window.geiSaveBusinessProfile=saveProfile;
window.geiLoadBusinessProfile=loadProfile;
})();
