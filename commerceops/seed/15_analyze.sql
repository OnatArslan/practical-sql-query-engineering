-- =====================================================================
-- CommerceOps · 15_analyze.sql   (dataset v1)
--
-- Planner istatistiklerini tazeler. Seed'den SONRA calistirilir.
--
-- Neden onemli:
--   Bulk INSERT sonrasi planner'in satir tahminleri eskidir. ANALYZE
--   calistirmadan alinan EXPLAIN ciktisi yanlis yorumlanir ("estimated
--   rows 1 ama actual rows 400.000" gibi). Module 9'a girmeden once
--   full profile uzerinde bu dosya MUTLAKA calistirilir.
-- =====================================================================

SET search_path = commerceops, public;

VACUUM (ANALYZE) commerceops.users;
VACUUM (ANALYZE) commerceops.addresses;
VACUUM (ANALYZE) commerceops.merchants;
VACUUM (ANALYZE) commerceops.merchant_members;
VACUUM (ANALYZE) commerceops.categories;
VACUUM (ANALYZE) commerceops.products;
VACUUM (ANALYZE) commerceops.product_categories;
VACUUM (ANALYZE) commerceops.orders;
VACUUM (ANALYZE) commerceops.order_items;
VACUUM (ANALYZE) commerceops.order_status_history;
VACUUM (ANALYZE) commerceops.payments;
VACUUM (ANALYZE) commerceops.refunds;
VACUUM (ANALYZE) commerceops.warehouses;
VACUUM (ANALYZE) commerceops.inventory_movements;
VACUUM (ANALYZE) commerceops.shipments;
VACUUM (ANALYZE) commerceops.shipment_items;
VACUUM (ANALYZE) commerceops.reviews;

-- Kontrol: istatistikler ne zaman toplandi, planner kac satir sanıyor?
SELECT relname                AS table_name,
       n_live_tup             AS planner_live_rows,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'commerceops'
ORDER BY n_live_tup DESC;
