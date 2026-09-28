-- Maintenance/reporting facts, not course exercises. Run with psql -X -q.
SET TIME ZONE 'UTC';
CREATE TEMP TABLE date_facts (column_name text, first_at timestamptz, last_at timestamptz);
DO $$ DECLARE r record; BEGIN
    FOR r IN SELECT table_name,column_name FROM information_schema.columns
             WHERE table_schema='public' AND data_type='timestamp with time zone' LOOP
        EXECUTE format('INSERT INTO date_facts SELECT %L,min(%I),max(%I) FROM %I',r.table_name||'.'||r.column_name,r.column_name,r.column_name,r.table_name);
    END LOOP;
END $$;
COPY (SELECT * FROM date_facts ORDER BY column_name) TO STDOUT CSV HEADER;
SELECT status,count(*) FROM orders GROUP BY status ORDER BY status;
SELECT status,count(*) FROM payments GROUP BY status ORDER BY status;
SELECT 'zero_order_customers' AS fact,count(*) FROM customers c WHERE NOT EXISTS(SELECT FROM orders o WHERE o.customer_id=c.id)
UNION ALL SELECT 'unsold_products',count(*) FROM products p WHERE NOT EXISTS(SELECT FROM order_items i WHERE i.product_id=p.id)
UNION ALL SELECT 'customer_1_orders',count(*) FROM orders WHERE customer_id=1
UNION ALL SELECT 'product_4_movements',count(*) FROM inventory_movements WHERE product_id=4
UNION ALL SELECT 'multi_attempt_orders',count(*) FROM (SELECT order_id FROM payments GROUP BY order_id HAVING count(*)>1) t
UNION ALL SELECT 'failed_only_orders',count(*) FROM (SELECT order_id FROM payments GROUP BY order_id HAVING bool_and(status='FAILED')) t;
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;
