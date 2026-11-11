import fs from 'node:fs';
import assert from 'node:assert/strict';

const html = fs.readFileSync('index.html', 'utf8');
const modules = fs.readFileSync('modules.js', 'utf8');
const manifest = JSON.parse(fs.readFileSync('manifest.webmanifest', 'utf8'));
const worker = fs.readFileSync('sw.js', 'utf8');

new Function(modules);
const inlineScripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map(match => match[1]).filter(source => source.trim());
assert.ok(inlineScripts.length > 0, 'index.html must contain application scripts');
inlineScripts.forEach(source => new Function(source));

for (const feature of [
  'erpRenderDashboard','erpRenderStock','erpRenderSales','erpRenderPurchases',
  'erpRenderReports','erpUploadDocument','create_sale_cart','receive_purchase_cart','Inteligência de gestão','overdueTotal'
]) assert.ok(modules.includes(feature) || html.includes(feature), 'Missing feature: ' + feature);
assert.ok(modules.includes('A receber') && modules.includes('A pagar') && modules.includes('Vencido'), 'Expanded financial report missing');
assert.ok(modules.includes('pageSize=500') && modules.includes('offset=\'+offset') && modules.includes('created_at.desc,id.desc'), 'Company data pagination missing');

for (const page of [
  'home','company','employees','products','stock','suppliers','customers',
  'sales','purchases','finance','documents','reports'
]) assert.ok(html.includes('data-page="' + page + '"'), 'Missing navigation page: ' + page);

assert.equal(manifest.display, 'standalone', 'PWA must be installable in standalone mode');
assert.equal(manifest.start_url, './index.html', 'PWA start URL must point to the app');
assert.ok(html.includes('rel="manifest"'), 'Manifest link missing');
assert.ok(html.includes("navigator.serviceWorker.register('./sw.js')"), 'Service worker registration missing');
const version = html.match(/modules\.js\?v=([^"']+)/)?.[1];
assert.ok(version, 'Versioned modules.js asset missing');
assert.ok(worker.includes('./modules.js?v=' + version), 'Service worker must cache the current modules.js version');
assert.ok(worker.includes('if (url.origin !== self.location.origin) return'), 'Service worker must not intercept external APIs');
assert.ok(html.includes('refreshSessionToken') && html.includes('refreshPromise'), 'Automatic session refresh missing');
assert.ok(html.includes('/auth/v1/recover') && html.includes('handleRecoveryLink'), 'Password recovery flow missing');
assert.ok(html.includes('window.startNewCompany') && html.includes('id=\"addCompany\"'), 'Multi-company creation and selection missing');
assert.ok(html.includes('handle_new_company_owner') && !html.includes("api('/rest/v1/company_members',{method:'POST'"), 'Company creation must rely on the database owner trigger without duplicate membership insertion');
assert.ok(modules.includes('payload={},oldRow'), 'Updates must not resend company_id or created_by');
assert.ok(html.includes('id="offlineMode"') && html.includes('MODO OFFLINE'), 'Offline launch screen missing');
assert.ok(html.includes("window.addEventListener('offline',showOfflineMode)"), 'Offline event handling missing');
assert.ok(html.includes("window.addEventListener('online'"), 'Online recovery handling missing');
assert.ok(html.includes("if(!navigator.onLine)throw Error('Modo offline"), 'Offline data access guard missing');
assert.ok(html.includes('beforeinstallprompt'), 'Install prompt handling missing');
assert.ok(worker.includes("gei360-shell-v12"), 'Offline shell cache version missing');
assert.ok(html.includes('session=saved;showOfflineMode();return;'), 'Offline session preservation missing');
assert.ok(!/service_role|sb_secret_/i.test(html + modules), 'Private Supabase key found in browser code');

for (const file of [
  '202611070001_employees.sql','202611080001_erp_modules.sql',
  '202611080002_finance_links.sql','202611080003_protect_linked_finance.sql',
  '202611090001_integrity_hardening.sql','202611100001_product_categories.sql',
  '202611100002_company_business_profiles.sql','202611100003_product_barcode_integrity.sql',
  '202611110001_employee_integrity.sql'
]) assert.ok(fs.existsSync('supabase/migrations/' + file), 'Missing migration: ' + file);

const coreSql = fs.readFileSync('supabase/migrations/202611080001_erp_modules.sql', 'utf8');
assert.ok(coreSql.includes('enable row level security'), 'RLS setup missing from core migration');
assert.ok(coreSql.includes("values ('company-documents', 'company-documents', false"), 'Private document bucket configuration missing');
assert.ok(coreSql.includes('create_sale_cart') && coreSql.includes('receive_purchase_cart'), 'Transactional sales/purchase RPCs missing');
const hardeningSql = fs.readFileSync('supabase/migrations/202611090001_integrity_hardening.sql', 'utf8');
assert.ok(hardeningSql.includes('quantity >= 0'), 'Zero-stock adjustment support missing');
assert.ok(hardeningSql.includes('revoke insert, update on table public.products'), 'Direct stock quantity insert/update protection missing');
assert.ok(hardeningSql.includes('grant insert (') && !/grant insert\s*\([^)]*stock_quantity/s.test(hardeningSql), 'Product stock must not be set directly on insert');
assert.ok(hardeningSql.includes('revoke insert, update on table public.financial_entries'), 'Financial source link protection missing');

assert.ok(fs.existsSync('docs/AI_ASSISTANT_ARCHITECTURE.md'), 'AI assistant security architecture missing');
assert.ok(fs.existsSync('docs/FISCAL_INTEGRATION_PLAN.md'), 'Fiscal integration plan missing');
assert.ok(fs.existsSync('docs/CLIENT_READINESS.md'), 'Client readiness checklist missing');
assert.ok(fs.existsSync('supabase/diagnostics/health_check.sql'), 'Supabase diagnostics missing');
assert.ok(fs.existsSync('supabase/diagnostics/FINALIZATION_PRECHECK.sql'), 'Consolidated finalization precheck missing');
const finalPrecheck = fs.readFileSync('supabase/diagnostics/FINALIZATION_PRECHECK.sql', 'utf8');
assert.ok(finalPrecheck.includes('from pg_policies') && finalPrecheck.includes('information_schema.table_privileges') && finalPrecheck.includes('pg_get_functiondef'), 'Finalization precheck must inspect RLS, grants and function definitions');
assert.ok(fs.existsSync('supabase/migrations/202611120001_api_privilege_hardening.sql'), 'Consolidated API privilege hardening migration missing');
assert.ok(fs.existsSync('supabase/INSTALL_GEI360_ALL.sql'), 'Single-transaction Supabase installer missing');
const installer = fs.readFileSync('supabase/INSTALL_GEI360_ALL.sql', 'utf8');
assert.ok(installer.includes('INSTALADOR SQL CONSOLIDADO') && installer.includes('202611120001_api_privilege_hardening.sql'), 'Installer must include the final security migration');
assert.equal((installer.match(/^begin;$/gim)||[]).length, 1, 'Installer must use one outer transaction');
assert.equal((installer.match(/^commit;$/gim)||[]).length, 1, 'Installer must use one outer transaction');

const privilegeHardening = fs.readFileSync('supabase/migrations/202611120001_api_privilege_hardening.sql', 'utf8');
assert.ok(privilegeHardening.includes('from anon, public'), 'Anonymous and PUBLIC table grants must be revoked');
assert.ok(privilegeHardening.includes('truncate, references, trigger, maintain'), 'Authenticated structural privileges must be revoked');
assert.ok(privilegeHardening.includes('grant execute on function public.create_sale_cart') && privilegeHardening.includes('grant execute on function public.receive_purchase_cart'), 'Authenticated transactional RPC grants must be preserved');
assert.ok(privilegeHardening.includes('from public, anon, authenticated'), 'Trigger-only functions must not be directly executable by API roles');
assert.ok(modules.includes('não um modelo de IA generativa'), 'Dashboard must disclose deterministic insights, not generative AI');

const profileJs = fs.readFileSync('business-profiles.js', 'utf8');
new Function(profileJs);
assert.ok(html.includes('business-profiles.js?v=20261110-01'), 'Business profile script not loaded');
assert.ok(worker.includes('./business-profiles.js?v=20261110-01'), 'Business profile script missing from offline shell');
assert.ok(worker.includes('gei360-shell-v11'), 'Offline shell cache version missing');
assert.ok(profileJs.includes("['ifood','iFood']"), 'iFood sales channel option missing');
assert.ok(profileJs.includes('aguardando integração oficial'), 'iFood integration must disclose pending official authorization');
assert.ok(profileJs.includes('geiProfileCompleteness') && profileJs.includes('Cadastro completo') && profileJs.includes('Cadastro incompleto'), 'Business profile completion status missing');
assert.ok(profileJs.includes('business_type') && profileJs.includes('sales_channels'), 'Business profile persistence fields missing');
assert.ok(!/access_token|refresh_token|client_secret|service_role/i.test(profileJs), 'Third-party secrets must not be stored in browser profile code');
const profileSql = fs.readFileSync('supabase/migrations/202611100002_company_business_profiles.sql', 'utf8');
assert.ok(profileSql.includes('enable row level security'), 'Business profile RLS missing');
assert.ok(profileSql.includes('is_company_member(company_id)'), 'Business profile member read policy missing');
assert.ok(profileSql.includes("array['owner','admin']"), 'Business profile owner/admin write guard missing');
assert.ok(profileSql.includes('revoke all on public.company_business_profiles from public, anon'), 'Anonymous access to business profiles must be revoked');
assert.ok(fs.existsSync('docs/IFOOD_INTEGRATION_PLAN.md'), 'Official iFood integration plan missing');


const barcodeModule = fs.readFileSync('modules.js', 'utf8');
assert.ok(barcodeModule.includes("['barcode','Código de barras','text']"), 'Product barcode field missing');
assert.ok(barcodeModule.includes("id=\"scanBarcode\"") && barcodeModule.includes("BarcodeDetector"), 'Camera barcode scanning missing');
assert.ok(barcodeModule.includes("getUserMedia"), 'Camera permission flow missing');
const barcodeSql = fs.readFileSync('supabase/migrations/202611100003_product_barcode_integrity.sql', 'utf8');
assert.ok(barcodeSql.includes('products_company_barcode_uidx'), 'Company-scoped unique barcode index missing');
assert.ok(barcodeSql.includes('gei360_normalize_product_barcode'), 'Barcode normalization trigger missing');
assert.ok(fs.existsSync('supabase/diagnostics/202611100003_barcode_preflight.sql'), 'Barcode preflight diagnostic missing');
assert.ok(fs.existsSync('docs/BARCODE_SETUP.md'), 'Barcode setup guide missing');

const categoryModule = fs.readFileSync('modules.js', 'utf8');
assert.ok(html.includes('data-page="categories"'), 'Categories navigation missing');
assert.ok(categoryModule.includes("categories:{table:'product_categories'"), 'Categories CRUD module missing');
assert.ok(categoryModule.includes("category_id") && categoryModule.includes("product_categories"), 'Product/category relationship missing');
const categorySql = fs.readFileSync('supabase/migrations/202611100001_product_categories.sql', 'utf8');
assert.ok(categorySql.includes('products_company_category_fk'), 'Company-scoped product/category foreign key missing');
assert.ok(categorySql.includes('enable row level security'), 'Product category RLS missing');
assert.ok(categorySql.includes('gei360_categories_member_guard'), 'Restrictive company-membership guard missing');
assert.ok(categorySql.includes('gei360_validate_product_category_company'), 'Cross-company category validation trigger missing');
assert.ok(fs.existsSync('supabase/diagnostics/202611100001_categories_preflight.sql'), 'Category preflight diagnostic missing');
assert.ok(fs.existsSync('docs/CATEGORIES_SETUP.md'), 'Category installation guide missing');


// Auditoria estática dos fluxos transacionais críticos (estoque, vendas, compras e financeiro).
const stockRpc = coreSql.slice(
  coreSql.indexOf('create or replace function public.record_stock_movement'),
  coreSql.indexOf('-- Venda atômica')
);
assert.ok(stockRpc.includes("p_movement_type not in ('in','out','adjustment')"), 'Stock RPC must validate movement type');
assert.ok(stockRpc.includes('p_quantity < 0') && stockRpc.includes("p_movement_type <> 'adjustment' and p_quantity = 0"), 'Stock RPC must validate movement quantity');
assert.ok(stockRpc.includes('for update') && stockRpc.includes('stock_quantity < p_quantity'), 'Stock RPC must lock product and prevent negative stock');
assert.ok(stockRpc.includes('has_company_role(p_company_id'), 'Stock RPC must verify company role');

const saleCartStart = coreSql.indexOf('create or replace function public.create_sale_cart');
const purchaseCartStart = coreSql.indexOf('create or replace function public.receive_purchase_cart');
const saleCartSql = coreSql.slice(saleCartStart, purchaseCartStart);
const purchaseCartSql = coreSql.slice(purchaseCartStart);
for (const [name, sql] of [['sale', saleCartSql], ['purchase', purchaseCartSql]]) {
  assert.ok(sql.includes("jsonb_typeof(p_items) is distinct from 'array'") && sql.includes('jsonb_array_length(p_items) = 0') || sql.includes('jsonb_array_length(p_items)=0'), name + ' cart must reject empty or invalid arrays');
  assert.ok(sql.includes('v_product_id = any(v_seen)'), name + ' cart must reject duplicate products');
  assert.ok(sql.includes('for update'), name + ' cart must lock products during validation');
  assert.ok(sql.includes('has_company_role(p_company_id'), name + ' cart must verify company role');
  assert.ok(/where id\s*=\s*v_product_id and company_id\s*=\s*p_company_id/i.test(sql), name + ' cart must scope products to the active company');
}
assert.ok(saleCartSql.includes('v_product.stock_quantity < v_quantity'), 'Sale cart must prevent selling above available stock');
assert.ok(saleCartSql.includes('v_total < 0'), 'Sale cart must reject discounts above subtotal');
assert.ok(saleCartSql.includes('insert into public.sale_items') && saleCartSql.includes("movement_type, quantity, note, created_by)"), 'Sale cart must persist items and stock movements atomically');
assert.ok(purchaseCartSql.includes('v_unit_cost<0') && purchaseCartSql.includes('v_quantity<=0'), 'Purchase cart must reject invalid quantity and cost');
assert.ok(purchaseCartSql.includes('insert into public.purchase_order_items') && purchaseCartSql.includes("movement_type,quantity,unit_cost,note,created_by"), 'Purchase cart must persist received items and stock movements atomically');

const financeProtection = fs.readFileSync('supabase/migrations/202611080003_protect_linked_finance.sql', 'utf8');
assert.ok(financeProtection.includes("new.status not in ('pending', 'paid')"), 'Linked financial entries must only allow pending or paid states');
assert.ok(financeProtection.includes('new.amount is distinct from old.amount') && financeProtection.includes('new.source_id is distinct from old.source_id'), 'Linked financial source data must remain immutable');
assert.ok(financeProtection.includes('before update or delete on public.financial_entries'), 'Linked financial protection trigger missing');
assert.ok(modules.includes("data-status-toggle") && modules.includes("paid_at:nextStatus==='pending'?null:new Date().toISOString()"), 'Finance status action must update payment timestamp');
assert.ok(modules.includes("await api('/rest/v1/rpc/create_sale_cart'") && modules.includes("await api('/rest/v1/rpc/receive_purchase_cart'"), 'UI must use transactional cart RPCs');


const employeeSecurity = fs.readFileSync('supabase/migrations/202611110001_employee_integrity.sql', 'utf8');
assert.ok(employeeSecurity.includes('gei360_guard_employee_integrity'), 'Employee immutable ownership trigger missing');
assert.ok(employeeSecurity.includes('new.company_id is distinct from old.company_id'), 'Employee company transfer must be blocked');
assert.ok(employeeSecurity.includes('new.created_by is distinct from old.created_by'), 'Employee creator changes must be blocked');
assert.ok(employeeSecurity.includes('as restrictive for all'), 'Employee membership restrictive RLS guard missing');
assert.ok(employeeSecurity.includes('gei360_employees_insert_guard') && employeeSecurity.includes('gei360_employees_update_guard') && employeeSecurity.includes('gei360_employees_delete_guard'), 'Employee role-specific restrictive RLS guards missing');
assert.ok(fs.existsSync('supabase/diagnostics/202611110001_employee_integrity_preflight.sql'), 'Employee security preflight diagnostic missing');
assert.ok(fs.existsSync('docs/EMPLOYEE_SECURITY.md'), 'Employee security installation guide missing');


// Auditoria de isolamento multiempresa: diagnóstico somente leitura e documentação.
const tenantAudit = fs.readFileSync('supabase/diagnostics/202611110002_tenant_isolation_audit.sql', 'utf8');
assert.ok(tenantAudit.includes("('companies'),('company_members'),('profiles'),('empresas')"), 'Tenant audit must inspect company identity tables and legacy empresas');
assert.ok(tenantAudit.includes('pg_get_functiondef(p.oid)'), 'Tenant audit must expose authorization function definitions');
assert.ok(tenantAudit.includes('p.prosecdef') && tenantAudit.includes('p.proconfig'), 'Tenant audit must inspect SECURITY DEFINER and search_path');
assert.ok(tenantAudit.includes('from pg_policies'), 'Tenant audit must inspect RLS policies');
assert.ok(tenantAudit.includes('information_schema.column_privileges'), 'Tenant audit must inspect sensitive column grants');
assert.ok(tenantAudit.includes('pg_constraint') && tenantAudit.includes('pg_indexes'), 'Tenant audit must inspect membership constraints and indexes');
assert.ok(tenantAudit.includes('SQL Editor usa privilégios administrativos'), 'Tenant audit must disclose that SQL Editor does not prove API isolation');
assert.ok(fs.existsSync('docs/TENANT_ISOLATION_AUDIT.md'), 'Tenant isolation audit guide missing');



// Os diagnósticos devem continuar executáveis antes da criação das tabelas opcionais.
const businessProfileCheck = fs.readFileSync('supabase/diagnostics/202611100002_business_profiles_check.sql', 'utf8');
assert.ok(businessProfileCheck.includes("to_regclass('public.company_business_profiles')"), 'Business profile preflight must detect a missing table');
assert.ok(businessProfileCheck.includes('if to_regclass') && businessProfileCheck.includes('return;'), 'Business profile preflight must safely skip absent tables');
const employeePreflight = fs.readFileSync('supabase/diagnostics/202611110001_employee_integrity_preflight.sql', 'utf8');
assert.ok(employeePreflight.includes("to_regclass('public.employees')") && employeePreflight.includes('return;'), 'Employee preflight must safely handle a missing table');
const barcodePreflight = fs.readFileSync('supabase/diagnostics/202611100003_barcode_preflight.sql', 'utf8');
assert.ok(barcodePreflight.includes("to_regclass('public.products')") && barcodePreflight.includes('return;'), 'Barcode preflight must safely handle a missing table');
assert.ok(tenantAudit.includes('aclexplode') && tenantAudit.includes('a.grantee=0'), 'Tenant audit must inspect PUBLIC function grants through ACL, not a pseudo-role');
assert.ok(!tenantAudit.includes("has_function_privilege('public'"), 'Tenant audit must not treat PUBLIC as a normal database role');

console.log('G.E.I360 validation passed: JavaScript, navigation, PWA, intelligence insights, AI/fiscal plans, privacy checks, migrations and transactional RPCs.');
