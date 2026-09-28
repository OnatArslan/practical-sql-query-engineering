-- Shared fixtures, applied by generate.sql inside the same transaction.
-- Other edge cases are structural generator rules, documented in the manifest.
INSERT INTO inventory_movements (id, product_id, quantity_delta, reason, created_at) VALUES
    (1, 1,  10, 'RESTOCK',    '2024-01-01 00:00:00+00'),
    (2, 1, -10, 'SALE',       '2024-01-02 00:00:00+00'),
    (3, 2,  10, 'RESTOCK',    '2024-01-01 00:00:00+00'),
    (4, 2,  -9, 'SALE',       '2024-01-02 00:00:00+00'),
    (5, 3,  10, 'RESTOCK',    '2024-01-01 00:00:00+00'),
    (6, 3, -11, 'ADJUSTMENT', '2024-01-02 00:00:00+00');
INSERT INTO inventory_movements
SELECT 7, products, 25, 'RESTOCK', timestamptz '2024-01-01 00:00:00+00' FROM config;
-- Same customer + timestamp, also exercising the scoped keyset pagination index.
UPDATE orders SET customer_id=1, created_at='2024-12-01 12:00:00+00' WHERE id IN (1,2);
-- Move dependent events by the same offset; these two orders remain PENDING.
UPDATE payments SET created_at = timestamptz '2024-12-01 12:00:00+00' + interval '5 minutes' WHERE order_id IN (1,2);
UPDATE order_status_history SET changed_at = timestamptz '2024-12-01 12:00:00+00' WHERE order_id IN (1,2);
