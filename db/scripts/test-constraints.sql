-- All invalid writes roll back in subtransactions; explicit IDs do not advance sequences.
CREATE FUNCTION pg_temp.reject(statement text, expected_state text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> expected_state THEN
            RAISE EXCEPTION 'Wrong rejection for %: % (%)', statement, SQLSTATE, SQLERRM;
        END IF;
        RETURN;
    END;
    RAISE EXCEPTION 'Invalid write was accepted: %', statement;
END $$;
SELECT pg_temp.reject('INSERT INTO customers VALUES (1,''duplicate@example.test'',''Duplicate'',''2024-01-01+00'')','23505');
SELECT pg_temp.reject('UPDATE customers SET email=(SELECT email FROM customers WHERE id=2) WHERE id=1','23505');
SELECT pg_temp.reject('UPDATE customers SET name=NULL WHERE id=1','23502');
SELECT pg_temp.reject('UPDATE categories SET parent_id=id WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE products SET category_id=-1 WHERE id=1','23503');
SELECT pg_temp.reject('UPDATE products SET price=-1 WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE products SET price=''NaN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE orders SET status=''UNKNOWN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE order_items SET quantity=0 WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE order_items SET unit_price=-1 WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE payments SET amount=-1 WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE payments SET status=''UNKNOWN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE shipments SET order_id=(SELECT order_id FROM shipments WHERE id=2) WHERE id=1','23505');
SELECT pg_temp.reject('UPDATE shipments SET status=''UNKNOWN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE shipments SET status=''DELIVERED'', delivered_at=shipped_at-interval ''1 second'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE order_status_history SET status=''UNKNOWN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE inventory_movements SET quantity_delta=0 WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE inventory_movements SET reason=''UNKNOWN'' WHERE id=1','23514');
SELECT pg_temp.reject('UPDATE inventory_movements SET quantity_delta=-1 WHERE id=1','23514');
\echo PASS: 19 invalid writes rejected with expected SQLSTATE
