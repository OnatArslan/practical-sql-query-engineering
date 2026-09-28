-- One generator for both profiles. psql -v profile=small|full, in a fresh DB.
SET TIME ZONE 'UTC';
CREATE TEMP TABLE config AS
SELECT :'profile' AS profile,
       CASE :'profile' WHEN 'small' THEN 2000 WHEN 'full' THEN 50000 END::bigint AS customers,
       CASE :'profile' WHEN 'small' THEN 500 WHEN 'full' THEN 10000 END::bigint AS products,
       CASE :'profile' WHEN 'small' THEN 15000 WHEN 'full' THEN 300000 END::bigint AS orders,
       CASE :'profile' WHEN 'small' THEN 40000 WHEN 'full' THEN 600000 END::bigint AS movements;
DO $$ BEGIN
    IF (SELECT customers IS NULL FROM config) THEN RAISE EXCEPTION 'Unknown profile'; END IF;
END $$;
-- Stateless integer hash: independent of random(), execution order, locale and clock.
CREATE FUNCTION pg_temp.h(k bigint, stream text) RETURNS bigint
LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT ('x' || substr(md5('minicommerce-v1:1729:' || stream || ':' || k::text), 1, 8))::bit(32)::bigint
$$;

INSERT INTO customers
SELECT i, 'customer' || lpad(i::text, 6, '0') || '@example.test',
       (ARRAY['Ada','Deniz','Maya','Emre','Lina','Can','Ece','Noah'])[1 + pg_temp.h(i,'name') % 8] || ' Customer ' || i,
       timestamptz '2023-01-01 00:00:00+00' + (pg_temp.h(i,'customer-date') % 31536000) * interval '1 second'
FROM config, generate_series(1, customers) AS i ORDER BY i;

-- Four roots, twelve children, sixteen grandchildren, eight great-grandchildren.
INSERT INTO categories
SELECT i, CASE WHEN i <= 4 THEN NULL WHEN i <= 16 THEN 1 + (i-5)/3
               WHEN i <= 32 THEN 5 + (i-17)%12 ELSE 17 + (i-33) END,
       CASE WHEN i <= 4 THEN (ARRAY['Electronics','Home','Clothing','Outdoors'])[i]
            ELSE 'Category ' || lpad(i::text, 2, '0') END
FROM generate_series(1,40) AS i ORDER BY i;

INSERT INTO products
SELECT i, CASE WHEN pg_temp.h(i,'category-skew')%10 < 6 THEN 33 + pg_temp.h(i,'category')%4
               ELSE 17 + pg_temp.h(i,'category')%24 END,
       'Product ' || lpad(i::text, 5, '0'),
       (500 + ((pg_temp.h(i,'price')%10000) * (pg_temp.h(i,'price')%10000) / 1000))::numeric / 100,
       i%10 <> 0,
       timestamptz '2023-01-01 00:00:00+00' + (pg_temp.h(i,'product-date')%31536000)*interval '1 second'
FROM config, generate_series(1,products) AS i ORDER BY i;

INSERT INTO orders
SELECT i,
       CASE WHEN i%20 = 0 THEN 1
            WHEN pg_temp.h(i,'customer-skew')%10 < 6 THEN 2 + pg_temp.h(i,'customer')%(customers/10-1)
            ELSE 2 + pg_temp.h(i,'customer')%(customers*9/10-1) END,
       CASE WHEN i%100 < 5 THEN 'PENDING' WHEN i%100 < 10 THEN 'CANCELLED'
            WHEN i%100 < 25 THEN 'PAID' WHEN i%100 < 40 THEN 'SHIPPED' ELSE 'COMPLETED' END,
       CASE WHEN i%4 = 0 THEN timestamptz '2024-01-01 00:00:00+00' + (pg_temp.h(i,'order-date')%13152)*interval '30 minutes'
            ELSE timestamptz '2024-10-01 00:00:00+00' + (pg_temp.h(i,'order-date')%4416)*interval '30 minutes' END
FROM config, generate_series(1,orders) AS i ORDER BY i;

INSERT INTO order_items
SELECT row_number() OVER (ORDER BY o.id, slot), o.id, p.id,
       CASE WHEN pg_temp.h(o.id*10+slot,'quantity')%10 < 8 THEN 1 ELSE 2 + pg_temp.h(o.id*10+slot,'quantity-large')%4 END,
       round(p.price * (80 + pg_temp.h(o.id*10+slot,'discount')%31)::numeric / 100, 2)
FROM config c CROSS JOIN orders o
CROSS JOIN LATERAL generate_series(1, (1+o.id%5)::integer) AS slot
JOIN products p ON p.id = CASE
    WHEN pg_temp.h(o.id*10+slot,'product-skew')%10 < 7
    THEN 1 + pg_temp.h(o.id*10+slot,'product')%(c.products/10)
    ELSE 1 + pg_temp.h(o.id*10+slot,'product')%(c.products*95/100) END
ORDER BY o.id, slot;

CREATE TEMP TABLE totals AS
SELECT order_id, sum(quantity*unit_price)::numeric(12,2) AS amount FROM order_items GROUP BY order_id;
CREATE UNIQUE INDEX ON totals(order_id);

INSERT INTO payments
SELECT row_number() OVER (ORDER BY o.id, attempt), o.id,
       CASE WHEN attempt = 1 AND o.id%5 = 0 THEN 'FAILED'
            WHEN o.status = 'PENDING' THEN 'PENDING'
            WHEN o.status = 'CANCELLED' AND o.id%100 IN (8,9) THEN 'REFUNDED'
            WHEN o.status = 'CANCELLED' THEN 'FAILED' ELSE 'SUCCEEDED' END,
       t.amount,
       CASE WHEN pg_temp.h(o.id,'provider')%10 < 7 THEN 'stripe'
            WHEN pg_temp.h(o.id,'provider')%10 < 9 THEN 'adyen' ELSE 'paypal' END,
       o.created_at + attempt*interval '5 minutes'
FROM orders o JOIN totals t ON t.order_id=o.id
CROSS JOIN LATERAL generate_series(1, CASE WHEN o.id%5=0 THEN 2 ELSE 1 END) AS attempt
ORDER BY o.id, attempt;

INSERT INTO shipments
SELECT row_number() OVER (ORDER BY id), id,
       CASE status WHEN 'COMPLETED' THEN 'DELIVERED' ELSE 'SHIPPED' END,
       created_at + interval '1 day',
       CASE WHEN status='COMPLETED' THEN created_at + interval '3 days' END
FROM orders WHERE status IN ('SHIPPED','COMPLETED') ORDER BY id;

INSERT INTO order_status_history
SELECT row_number() OVER (ORDER BY o.id, event.minutes), o.id, event.status,
       o.created_at + event.minutes * interval '1 minute'
FROM orders o CROSS JOIN LATERAL (
    SELECT 'PENDING'::text AS status, 0 AS minutes
    UNION ALL SELECT 'PENDING', 6 WHERE o.id%5=0 -- Retry queued after first failed payment.
    UNION ALL SELECT 'PAID', 15 WHERE o.status IN ('PAID','SHIPPED','COMPLETED') OR o.id%100 IN (8,9)
    UNION ALL SELECT 'SHIPPED', 1440 WHERE o.status IN ('SHIPPED','COMPLETED')
    UNION ALL SELECT 'COMPLETED', 4320 WHERE o.status='COMPLETED'
    UNION ALL SELECT 'CANCELLED', 60 WHERE o.status='CANCELLED'
) event ORDER BY o.id, event.minutes;

-- Products 1..3 and the last product are reserved for explicit ledger fixtures.
-- Remaining movements are a historical sample, not a full accounting of order_items.
INSERT INTO inventory_movements
SELECT i, CASE WHEN i%5=0 THEN 4
               ELSE 4 + ((pg_temp.h(i,'inventory-product')%10000) * (pg_temp.h(i,'inventory-product')%10000) * (products-4) / 100000000) END,
       CASE WHEN i%10 < 4 THEN (1 + pg_temp.h(i,'restock')%40)::integer
            ELSE -(1 + pg_temp.h(i,'sale')%12)::integer END,
       CASE WHEN i%10 < 4 THEN 'RESTOCK' ELSE 'SALE' END,
       timestamptz '2024-01-01 00:00:00+00' + (pg_temp.h(i,'movement-date')%31622400)*interval '1 second'
FROM config, generate_series(8, movements) AS i ORDER BY i;
\ir edge_cases.sql

-- Explicit fixture IDs must never collide with subsequent course INSERTs.
DO $$ DECLARE t text; BEGIN
    FOREACH t IN ARRAY ARRAY['customers','categories','products','orders','order_items','payments','shipments','order_status_history','inventory_movements'] LOOP
        EXECUTE format('SELECT setval(pg_get_serial_sequence(%L, ''id''), (SELECT max(id) FROM %I), true)', t, t);
    END LOOP;
END $$;
