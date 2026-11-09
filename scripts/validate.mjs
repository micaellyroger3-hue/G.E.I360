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
assert.ok(modules.includes('payload={},oldRow'), 'Updates must not resend company_id or created_by');
assert.ok(html.includes('id="offlineMode"') && html.includes('MODO OFFLINE'), 'Offline launch screen missing');
assert.ok(html.includes("window.addEventListener('offline',showOfflineMode)"), 'Offline event handling missing');
assert.ok(html.includes("window.addEventListener('online'"), 'Online recovery handling missing');
assert.ok(html.includes("if(!navigator.onLine)throw Error('Modo offline"), 'Offline data access guard missing');
assert.ok(html.includes('beforeinstallprompt'), 'Install prompt handling missing');
assert.ok(worker.includes("gei360-shell-v9"), 'Offline shell cache version missing');
assert.ok(html.includes('session=saved;showOfflineMode();return;'), 'Offline session preservation missing');
assert.ok(!/service_role|sb_secret_/i.test(html + modules), 'Private Supabase key found in browser code');

for (const file of [
  '202611070001_employees.sql','202611080001_erp_modules.sql',
  '202611080002_finance_links.sql','202611080003_protect_linked_finance.sql',
  '202611090001_integrity_hardening.sql'
]) assert.ok(fs.existsSync('supabase/migrations/' + file), 'Missing migration: ' + file);

const coreSql = fs.readFileSync('supabase/migrations/202611080001_erp_modules.sql', 'utf8');
assert.ok(coreSql.includes('enable row level security'), 'RLS setup missing from core migration');
assert.ok(coreSql.includes("values ('company-documents', 'company-documents', false"), 'Private document bucket configuration missing');
assert.ok(coreSql.includes('create_sale_cart') && coreSql.includes('receive_purchase_cart'), 'Transactional sales/purchase RPCs missing');
const hardeningSql = fs.readFileSync('supabase/migrations/202611090001_integrity_hardening.sql', 'utf8');
assert.ok(hardeningSql.includes('quantity >= 0'), 'Zero-stock adjustment support missing');
assert.ok(hardeningSql.includes('revoke update on table public.products'), 'Direct stock quantity update protection missing');
assert.ok(hardeningSql.includes('revoke insert, update on table public.financial_entries'), 'Financial source link protection missing');

assert.ok(fs.existsSync('docs/AI_ASSISTANT_ARCHITECTURE.md'), 'AI assistant security architecture missing');
assert.ok(fs.existsSync('docs/FISCAL_INTEGRATION_PLAN.md'), 'Fiscal integration plan missing');
assert.ok(fs.existsSync('docs/CLIENT_READINESS.md'), 'Client readiness checklist missing');
assert.ok(fs.existsSync('supabase/diagnostics/health_check.sql'), 'Supabase diagnostics missing');
assert.ok(modules.includes('não um modelo de IA generativa'), 'Dashboard must disclose deterministic insights, not generative AI');
console.log('G.E.I360 validation passed: JavaScript, navigation, PWA, intelligence insights, AI/fiscal plans, privacy checks, migrations and transactional RPCs.');
