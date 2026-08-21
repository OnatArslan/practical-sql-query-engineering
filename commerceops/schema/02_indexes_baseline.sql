-- =====================================================================
-- CommerceOps · 02_indexes_baseline.sql
--
-- BASELINE index seti. Bilincli olarak EKSIKTIR.
--
-- Buradaki amac "iyi indexlenmis bir veritabani" vermek degil; Module 9'da
-- olcumle index degerlendirmesi yapabilecegin gercekci bir baslangic
-- noktasi vermek. Asagida hangi index'lerin BILEREK eklenmedigi de yazili.
--
-- Kural: index onerisi full dataset uzerinde EXPLAIN ANALYZE olcumu
--        olmadan yapilmaz.
-- =====================================================================

SET search_path = commerceops, public;

-- Child tablolarin parent'a bakan FK kolonlari (en temel erisim yollari)
CREATE INDEX idx_addresses_user            ON addresses(user_id);
CREATE INDEX idx_member_user               ON merchant_members(user_id);
CREATE INDEX idx_products_merchant         ON products(merchant_id);
CREATE INDEX idx_categories_parent         ON categories(parent_id);
CREATE INDEX idx_pc_category               ON product_categories(category_id);
CREATE INDEX idx_orders_customer           ON orders(customer_id);
CREATE INDEX idx_items_order               ON order_items(order_id);
CREATE INDEX idx_items_product             ON order_items(product_id);
CREATE INDEX idx_history_order             ON order_status_history(order_id);
CREATE INDEX idx_payments_order            ON payments(order_id);
CREATE INDEX idx_refunds_payment           ON refunds(payment_id);
CREATE INDEX idx_warehouses_merchant       ON warehouses(merchant_id);
CREATE INDEX idx_movements_product         ON inventory_movements(product_id);
CREATE INDEX idx_movements_warehouse       ON inventory_movements(warehouse_id);
CREATE INDEX idx_shipments_order           ON shipments(order_id);
CREATE INDEX idx_shipitems_shipment        ON shipment_items(shipment_id);
CREATE INDEX idx_shipitems_order_item      ON shipment_items(order_item_id);
CREATE INDEX idx_reviews_product           ON reviews(product_id);

-- ---------------------------------------------------------------------
-- BILEREK EKLENMEYENLER (Module 9'da olcup kendin karar vereceksin):
--
--   order_items(merchant_id)              -> merchant order list endpoint'inin kalbi
--   orders(placed_at) / orders(created_at)-> tarih araligi raporlari
--   orders(status)                        -> status filtresi
--   payments(status, settled_at)          -> revenue reporting
--   products(name) / trigram index        -> product search
--   inventory_movements(occurred_at)      -> hareket zaman araligi
--   payments(provider_response) GIN       -> JSONB sorgulari
--   composite key-set pagination index    -> (merchant, created_at DESC, id DESC)
--
-- Bunlarin hicbirini simdiden ekleme. Once dogru query, sonra olcum.
-- ---------------------------------------------------------------------
