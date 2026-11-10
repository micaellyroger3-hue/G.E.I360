/* G.E.I360 | Perfis empresariais e canais de venda
 * O perfil recomenda módulos; não finge conectar serviços externos.
 * Segredos e tokens de integrações nunca são armazenados no navegador.
 */
(function(){
'use strict';
const TYPES=[
 ['restaurant','Restaurante / lanchonete'],
 ['grocery','Mercado / mercearia'],
 ['retail','Loja / comércio'],
 ['services','Prestação de serviços'],
 ['distributor','Distribuidora / atacado'],
 ['ecommerce','E-commerce'],
 ['construction','Construção / obras'],
 ['other','Outro ramo']
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
 'Cardápio e produtos':'products','Estoque':'products','Movimentações de estoque':'stock',
 'Vendas e pedidos':'sales','Compras':'purchases','Fornecedores':'suppliers',
 'Clientes':'customers','Financeiro':'finance','Documentos':'documents',
 'Relatórios':'reports','Funcionários':'employees'
};
const MODULES={
 restaurant:['Produtos e cardápio','Estoque e ficha de insumos','Pedidos e vendas','Compras e fornecedores','Clientes','Financeiro','Entregas','Documentos e relatórios'],
 grocery:['Produtos e códigos de barras','Estoque e validade','Compras e fornecedores','Vendas e caixa','Clientes','Financeiro','Documentos e relatórios'],
 retail:['Catálogo e preços','Estoque','Vendas e caixa','Compras e fornecedores','Clientes','Financeiro','Documentos e relatórios'],
 services:['Catálogo de serviços','Orçamentos e ordens de serviço','Agenda e equipe','Clientes','Financeiro','Documentos e relatórios'],
 distributor:['Catálogo e tabela de preços','Estoque e depósitos','Compras e fornecedores','Pedidos e vendas','Clientes','Logística','Financeiro e relatórios'],
 ecommerce:['Catálogo e preços','Estoque','Pedidos e vendas','Clientes','Expedição e entregas','Financeiro','Canais e relatórios'],
 construction:['Obras e projetos','Materiais e estoque','Compras e fornecedores','Equipe','Clientes e contratos','Financeiro','Documentos e relatórios'],
 other:['Cadastros','Estoque (se aplicável)','Vendas e serviços','Compras','Clientes e fornecedores','Financeiro','Documentos e relatórios']
};
const $id=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let currentProfile=null;
function selectedChannels(){return CHANNELS.filter(([key])=>$id('gei_channel_'+key)?.checked).map(([key])=>key)}
function profileMarkup(){
 const typeOptions=TYPES.map(([v,l])=>'<option value="'+v+'">'+l+'</option>').join('');
 const channelOptions=CHANNELS.map(([v,l])=>'<label style="display:flex;gap:8px;align-items:center;border:1px solid #e5eaf1;border-radius:8px;padding:9px;font-size:12px"><input type="checkbox" id="gei_channel_'+v+'" value="'+v+'"> '+l+'</label>').join('');
 return '<section class="card" id="geiBusinessProfile"><h3 style="margin:0 0 6px">Perfil inteligente da empresa</h3><p class="muted" style="margin:0 0 12px">Escolha o ramo e os canais utilizados. O G.E.I360 organiza os módulos recomendados para esse negócio.</p><div class="field"><label for="geiBusinessType">Ramo de atividade</label><select id="geiBusinessType">'+typeOptions+'</select></div><div class="field"><label>Canais de venda e atendimento</label><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:7px">'+channelOptions+'</div></div><div id="geiProfilePreview" class="notice" style="margin-top:12px">Selecione o ramo para visualizar os módulos recomendados.</div><div id="geiIfodPanel" class="notice hidden"></div><p id="geiProfileStatus" class="muted" style="font-size:11px;margin:8px 0 0">O perfil será salvo junto com os dados da empresa.</p></section>';
}
function updatePreview(){
 const type=$id('geiBusinessType')?.value||'other';
 const channels=selectedChannels();
 const modules=MODULES[type]||MODULES.other;
 const preview=$id('geiProfilePreview');
 if(preview){preview.innerHTML='<b>Módulos recomendados (toque para abrir):</b><div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:8px">'+modules.map(x=>'<button type="button" class="alt small" data-gei-page="'+(ROUTES[x]||'')+'">'+esc(x)+'</button>').join('')+'</div>';preview.querySelectorAll('[data-gei-page]').forEach(button=>button.addEventListener('click',()=>{if(button.dataset.geiPage)setPage(button.dataset.geiPage)}));}
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
  const rows=await api('/rest/v1/company_business_profiles?select=company_id,business_type,sales_channels,created_by,updated_at&company_id=eq.'+encodeURIComponent(companyId)+'&limit=1');
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
 const payload={company_id:companyId,business_type:$id('geiBusinessType')?.value||'other',sales_channels:selectedChannels()};
 try{
  if(currentProfile){
   await api('/rest/v1/company_business_profiles?company_id=eq.'+encodeURIComponent(companyId),{method:'PATCH',body:payload});
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
 type.value=currentProfile?.business_type||'other';
 for(const [key] of CHANNELS){const el=$id('gei_channel_'+key);if(el)el.checked=(currentProfile?.sales_channels||[]).includes(key)}
 type.onchange=updatePreview;
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
