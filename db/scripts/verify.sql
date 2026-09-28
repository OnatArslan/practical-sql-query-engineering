\pset pager off
\o /dev/null
SET TIME ZONE 'UTC';
CREATE FUNCTION pg_temp.assert(ok boolean, message text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', message; END IF; END $$;
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT pg_temp.assert(current_setting('server_version_num')::integer BETWEEN 170000 AND 179999, 'PostgreSQL 17');
SELECT pg_temp.assert((SELECT datcollate='C' AND datctype='C' AND pg_encoding_to_char(encoding)='UTF8'
                      FROM pg_database WHERE datname=current_database()), 'C locale / UTF8');
CREATE TEMP TABLE expected (profile text, table_name text, row_count bigint);
\copy expected FROM '/workspace/db/seed/expected-counts.csv' WITH CSV HEADER
DELETE FROM expected WHERE profile <> :'profile';
SELECT pg_temp.assert((SELECT count(*)=9 FROM expected), 'manifest has exactly nine tables');

-- Explicit contract: order, PostgreSQL type, NOT NULL and identity behavior.
CREATE TEMP TABLE columns_contract (table_name text, definition text);
INSERT INTO columns_contract VALUES
('customers','id:bigint:!|email:character varying(254):!|name:character varying(200):!|created_at:timestamp with time zone:!'),
('categories','id:bigint:!|parent_id:bigint:?|name:character varying(120):!'),
('products','id:bigint:!|category_id:bigint:!|name:character varying(200):!|price:numeric(12,2):!|active:boolean:!|created_at:timestamp with time zone:!'),
('orders','id:bigint:!|customer_id:bigint:!|status:character varying(20):!|created_at:timestamp with time zone:!'),
('order_items','id:bigint:!|order_id:bigint:!|product_id:bigint:!|quantity:integer:!|unit_price:numeric(12,2):!'),
('payments','id:bigint:!|order_id:bigint:!|status:character varying(20):!|amount:numeric(12,2):!|provider:character varying(40):!|created_at:timestamp with time zone:!'),
('shipments','id:bigint:!|order_id:bigint:!|status:character varying(20):!|shipped_at:timestamp with time zone:?|delivered_at:timestamp with time zone:?'),
('order_status_history','id:bigint:!|order_id:bigint:!|status:character varying(20):!|changed_at:timestamp with time zone:!'),
('inventory_movements','id:bigint:!|product_id:bigint:!|quantity_delta:integer:!|reason:character varying(30):!|created_at:timestamp with time zone:!');
CREATE TEMP TABLE actual_counts (table_name text, row_count bigint);
DO $$ DECLARE r record; actual text; n bigint; seq_value bigint; BEGIN
    IF (SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind IN ('r','p')) <> 9 THEN
        RAISE EXCEPTION 'Expected exactly nine business tables';
    END IF;
    FOR r IN SELECT e.*, c.definition FROM expected e JOIN columns_contract c USING(table_name) LOOP
        PERFORM pg_temp.assert(to_regclass('public.'||r.table_name) IS NOT NULL, 'missing table '||r.table_name);
        SELECT string_agg(attname||':'||format_type(atttypid,atttypmod)||':'||CASE WHEN attnotnull THEN '!' ELSE '?' END, '|' ORDER BY attnum)
        INTO actual FROM pg_attribute WHERE attrelid=to_regclass('public.'||r.table_name) AND attnum>0 AND NOT attisdropped;
        PERFORM pg_temp.assert(actual=r.definition, 'column contract '||r.table_name);
        PERFORM pg_temp.assert((SELECT attidentity='d' FROM pg_attribute WHERE attrelid=to_regclass(r.table_name) AND attname='id'), 'identity '||r.table_name);
        EXECUTE format('SELECT count(*) FROM %I',r.table_name) INTO n;
        PERFORM pg_temp.assert(n=r.row_count, format('%s count: expected %s, got %s',r.table_name,r.row_count,n));
        INSERT INTO actual_counts VALUES (r.table_name,n);
        EXECUTE format('SELECT last_value FROM %s',pg_get_serial_sequence(r.table_name,'id')) INTO seq_value;
        EXECUTE format('SELECT max(id) FROM %I',r.table_name) INTO n;
        PERFORM pg_temp.assert(seq_value=n, 'identity sequence reset '||r.table_name);
    END LOOP;
END $$;
\o
TABLE actual_counts;
\o /dev/null

-- Check exact constraint inventory, validation and the rows themselves.
SELECT pg_temp.assert((SELECT count(*)=38 AND bool_and(convalidated) FROM pg_constraint
    WHERE connamespace='public'::regnamespace), '38 validated constraints');
SELECT pg_temp.assert((SELECT count(*)=9 FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='p'), 'nine primary keys');
SELECT pg_temp.assert((SELECT count(*)=9 FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='f'), 'nine foreign keys');
SELECT pg_temp.assert((SELECT count(*)=18 FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='c'), 'eighteen CHECK constraints');
SELECT pg_temp.assert((SELECT count(*)=2 FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='u'
    AND conname IN ('customers_email_key','shipments_order_key')), 'email / shipment uniqueness');
CREATE TEMP TABLE expected_catalog (kind text, name text, definition text);
\copy expected_catalog FROM '/workspace/db/schema/expected-catalog.csv' WITH CSV HEADER
CREATE TEMP TABLE actual_catalog AS
SELECT 'constraint' AS kind, t.relname||'.'||c.conname AS name, pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid WHERE c.connamespace='public'::regnamespace
UNION ALL
SELECT 'index',tablename||'.'||indexname,indexdef FROM pg_indexes WHERE schemaname='public';
SELECT pg_temp.assert(NOT EXISTS (
    (SELECT * FROM actual_catalog EXCEPT SELECT * FROM expected_catalog)
    UNION ALL (SELECT * FROM expected_catalog EXCEPT SELECT * FROM actual_catalog)
), 'exact PK/FK/CHECK/UNIQUE definitions and index catalog');
DO $$ DECLARE r record; bad boolean; BEGIN
    FOR r IN SELECT conrelid::regclass AS child, confrelid::regclass AS parent,
                    (SELECT attname FROM pg_attribute WHERE attrelid=conrelid AND attnum=conkey[1]) AS child_key,
                    (SELECT attname FROM pg_attribute WHERE attrelid=confrelid AND attnum=confkey[1]) AS parent_key,
                    conname FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='f' LOOP
        EXECUTE format('SELECT EXISTS (SELECT FROM %s c LEFT JOIN %s p ON c.%I=p.%I WHERE c.%I IS NOT NULL AND p.%I IS NULL)',
            r.child,r.parent,r.child_key,r.parent_key,r.child_key,r.parent_key) INTO bad;
        PERFORM pg_temp.assert(NOT bad, 'FK orphans '||r.conname);
    END LOOP;
    FOR r IN SELECT conrelid::regclass AS tbl, conname, pg_get_expr(conbin,conrelid) AS expression
             FROM pg_constraint WHERE connamespace='public'::regnamespace AND contype='c' LOOP
        EXECUTE format('SELECT EXISTS (SELECT FROM %s WHERE NOT (%s))', r.tbl, r.expression) INTO bad;
        PERFORM pg_temp.assert(NOT bad, 'CHECK rows '||r.conname);
    END LOOP;
END $$;
CREATE TEMP TABLE expected_indexes (name text, table_name text, columns text);
INSERT INTO expected_indexes VALUES
('categories_parent_idx','categories','parent_id'),
('products_category_idx','products','category_id'),
('orders_customer_created_id_idx','orders','customer_id, created_at, id'),
('order_items_order_idx','order_items','order_id'),
('order_items_product_idx','order_items','product_id'),
('payments_order_created_id_idx','payments','order_id, created_at, id'),
('order_status_history_order_changed_id_idx','order_status_history','order_id, changed_at, id'),
('inventory_movements_product_created_id_idx','inventory_movements','product_id, created_at, id');
SELECT pg_temp.assert(NOT EXISTS (
    SELECT FROM expected_indexes e LEFT JOIN pg_indexes i ON i.schemaname='public' AND i.indexname=e.name AND i.tablename=e.table_name
    WHERE i.indexdef IS NULL OR i.indexdef <> 'CREATE INDEX '||e.name||' ON public.'||e.table_name||' USING btree ('||e.columns||')'
), 'eight sensible FK indexes and correct column order');
SELECT pg_temp.assert((SELECT bool_and(indisvalid AND indisready) FROM pg_index WHERE indrelid IN (SELECT to_regclass(table_name) FROM expected)), 'all indexes valid');

-- Explicit edge-case SQL assertions; NULL must fail, never silently pass.
SELECT pg_temp.assert(EXISTS(SELECT FROM customers c WHERE NOT EXISTS (SELECT FROM orders o WHERE o.customer_id=c.id)), 'zero-order customer');
SELECT pg_temp.assert((SELECT count(*) FROM orders WHERE customer_id=1) >= (SELECT row_count/20 FROM expected WHERE table_name='orders'), 'high-volume customer');
SELECT pg_temp.assert(EXISTS(SELECT FROM products p WHERE NOT EXISTS (SELECT FROM order_items i WHERE i.product_id=p.id)), 'unsold product');
SELECT pg_temp.assert(EXISTS(SELECT FROM products WHERE NOT active), 'inactive product');
SELECT pg_temp.assert(EXISTS(SELECT FROM payments GROUP BY order_id HAVING count(*)=1), 'single payment order');
SELECT pg_temp.assert(EXISTS(SELECT FROM payments GROUP BY order_id HAVING count(*)>1), 'multiple payment attempts');
SELECT pg_temp.assert(EXISTS(SELECT FROM payments GROUP BY order_id HAVING bool_and(status='FAILED')), 'failed-only order');
SELECT pg_temp.assert(EXISTS(SELECT FROM payments f JOIN payments s USING(order_id) WHERE f.status='FAILED' AND s.status='SUCCEEDED' AND f.created_at<s.created_at), 'success after failure');
SELECT pg_temp.assert(EXISTS(SELECT FROM orders o WHERE NOT EXISTS(SELECT FROM shipments s WHERE s.order_id=o.id)), 'order without shipment');
SELECT pg_temp.assert(EXISTS(SELECT FROM shipments WHERE status='DELIVERED' AND delivered_at IS NOT NULL), 'delivered shipment');
SELECT pg_temp.assert(EXISTS(SELECT FROM orders WHERE status='CANCELLED'), 'cancelled order');
SELECT pg_temp.assert(EXISTS(SELECT FROM orders GROUP BY customer_id,created_at HAVING count(*)>1), 'pagination timestamp tie for one customer');

WITH RECURSIVE tree AS (
    SELECT id, parent_id, ARRAY[id] AS path, false AS cycle FROM categories
    UNION ALL
    SELECT c.id,c.parent_id,t.path||c.id,c.id=ANY(t.path) FROM tree t JOIN categories c ON c.id=t.parent_id WHERE NOT t.cycle
)
SELECT pg_temp.assert(NOT bool_or(cycle) AND max(cardinality(path))=4, 'acyclic four-level hierarchy') FROM tree;
CREATE TEMP TABLE inventory_facts AS
SELECT product_id,count(*) AS movements,sum(quantity_delta) AS net FROM inventory_movements GROUP BY product_id;
SELECT pg_temp.assert(EXISTS(SELECT FROM inventory_facts WHERE movements>=1000), 'many inventory movements');
SELECT pg_temp.assert(EXISTS(SELECT FROM inventory_facts WHERE movements=1), 'very few inventory movements');
SELECT pg_temp.assert((SELECT net=0 FROM inventory_facts WHERE product_id=1), 'zero inventory net');
SELECT pg_temp.assert((SELECT net=1 FROM inventory_facts WHERE product_id=2), 'positive inventory net');
SELECT pg_temp.assert((SELECT net=-1 FROM inventory_facts WHERE product_id=3), 'near-zero negative inventory net');
SELECT pg_temp.assert(EXISTS(SELECT FROM inventory_movements WHERE quantity_delta>0) AND EXISTS(SELECT FROM inventory_movements WHERE quantity_delta<0), 'both movement signs');

-- Dataset relationships beyond individual FK/CHECK constraints.
SELECT pg_temp.assert(NOT EXISTS(SELECT FROM orders o WHERE NOT EXISTS(SELECT FROM order_items i WHERE i.order_id=o.id)), 'every order has items');
SELECT pg_temp.assert(EXISTS(SELECT FROM order_items i JOIN products p ON p.id=i.product_id WHERE i.unit_price<>p.price), 'historical price differs');
SELECT pg_temp.assert(NOT EXISTS(SELECT FROM orders o JOIN customers c ON c.id=o.customer_id WHERE o.created_at<c.created_at), 'order after customer registration');
SELECT pg_temp.assert(NOT EXISTS(SELECT FROM payments p JOIN orders o ON o.id=p.order_id WHERE p.created_at<o.created_at), 'payment chronology');
SELECT pg_temp.assert(NOT EXISTS(
    SELECT FROM payments p JOIN (SELECT order_id,sum(quantity*unit_price) AS total FROM order_items GROUP BY order_id) t USING(order_id)
    WHERE p.amount<>t.total), 'payment attempt amount equals historical order total');
SELECT pg_temp.assert(NOT EXISTS(
    SELECT FROM orders o LEFT JOIN shipments s ON s.order_id=o.id
    WHERE (o.status IN ('SHIPPED','COMPLETED')) IS DISTINCT FROM (s.id IS NOT NULL)
       OR s.shipped_at<o.created_at OR (o.status='COMPLETED' AND s.status<>'DELIVERED')
), 'shipment/order consistency');
CREATE TEMP TABLE history_facts AS
SELECT order_id,status,changed_at,
       lag(changed_at) OVER (PARTITION BY order_id ORDER BY changed_at,id) AS previous_at,
       row_number() OVER (PARTITION BY order_id ORDER BY changed_at,id) AS first_rn,
       row_number() OVER (PARTITION BY order_id ORDER BY changed_at DESC,id DESC) AS last_rn
FROM order_status_history;
-- Planner statistics are essential for the large temporary assertion relation.
CREATE UNIQUE INDEX ON history_facts(order_id) WHERE last_rn=1;
ANALYZE history_facts;
SELECT pg_temp.assert(NOT EXISTS(
    SELECT FROM orders o LEFT JOIN history_facts h ON h.order_id=o.id AND h.last_rn=1 WHERE h.status IS DISTINCT FROM o.status
), 'every order has history; latest status matches order');
SELECT pg_temp.assert(NOT EXISTS(
    SELECT FROM history_facts h JOIN orders o ON o.id=h.order_id
    WHERE h.changed_at<o.created_at OR h.previous_at>=h.changed_at
       OR (h.first_rn=1 AND (h.status<>'PENDING' OR h.changed_at<>o.created_at))
), 'strictly ordered history begins with PENDING at order creation');

-- Stable UTC envelope for every timestamp column, no wall-clock values.
DO $$ DECLARE r record; bad boolean; BEGIN
    FOR r IN SELECT table_name,column_name FROM information_schema.columns
             WHERE table_schema='public' AND data_type='timestamp with time zone' LOOP
        EXECUTE format('SELECT EXISTS(SELECT FROM %I WHERE %I < timestamptz ''2023-01-01 00:00:00+00'' OR %I >= timestamptz ''2025-01-04 00:00:00+00'')',
                       r.table_name,r.column_name,r.column_name) INTO bad;
        PERFORM pg_temp.assert(NOT bad, 'UTC date envelope '||r.table_name||'.'||r.column_name);
    END LOOP;
END $$;
SELECT pg_temp.assert((SELECT count(*) FILTER (WHERE created_at>='2024-10-01 00:00:00+00')::numeric/count(*) FROM orders) BETWEEN .74 AND .76, 'Q4 seasonal skew');
SELECT pg_temp.assert((SELECT count(*) FILTER (WHERE customer_id<= (SELECT row_count/10 FROM expected WHERE table_name='customers'))::numeric/count(*) FROM orders)>.6, 'customer skew');
SELECT pg_temp.assert((SELECT count(*) FILTER (WHERE product_id<= (SELECT row_count/10 FROM expected WHERE table_name='products'))::numeric/count(*) FROM order_items)>.7, 'product popularity skew');
COMMIT;
\o
\echo PASS: schema, exact counts, all FK orphans, edge cases, chronology and skew
