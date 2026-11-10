# G.E.I360 — Integridade e leitura de códigos de barras

O cadastro de produtos já possui campo de código de barras e opção de leitura pela câmera quando o navegador oferece suporte a `BarcodeDetector`. Também aceita leitor USB/Bluetooth (que funciona como teclado) e digitação manual.

## Proteção contra duplicidade

A migração `202611100003_product_barcode_integrity.sql`:
- Normaliza espaços no início e no fim do código.
- Converte valores vazios em NULL.
- Impede que a mesma empresa cadastre o mesmo código em dois produtos.
- Permite que empresas diferentes usem o mesmo código.
- Não apaga nem reescreve códigos existentes, além de remover espaços externos quando o produto for salvo.

## Instalação segura

1. Execute primeiro `supabase/diagnostics/202611100003_barcode_preflight.sql` no SQL Editor.
2. Se a consulta de duplicidades retornar linhas, corrija os produtos repetidos antes de continuar.
3. Se não houver duplicidades, revise e execute `supabase/migrations/202611100003_product_barcode_integrity.sql`.
4. Teste com um produto fictício: salve um código, tente repeti-lo na mesma empresa (deve ser bloqueado) e use o mesmo código em outra empresa (deve ser permitido).

A migração ainda não foi aplicada ao Supabase. Não a execute antes de revisar o diagnóstico.
