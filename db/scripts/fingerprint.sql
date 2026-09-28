SET TIME ZONE 'UTC';
SET datestyle = 'ISO, YMD';
BEGIN ISOLATION LEVEL REPEATABLE READ;
CREATE TEMP TABLE fingerprints (table_name text, row_count bigint, content_md5 text);
DO $$ DECLARE t text; BEGIN
    FOREACH t IN ARRAY ARRAY['customers','categories','products','orders','order_items','payments','shipments','order_status_history','inventory_movements'] LOOP
        EXECUTE format('INSERT INTO fingerprints SELECT %L, count(*), md5(string_agg(md5(row_to_json(t)::text), '''' ORDER BY id)) FROM %I t', t, t);
    END LOOP;
END $$;
COPY (SELECT * FROM fingerprints ORDER BY table_name) TO STDOUT WITH CSV HEADER;
COMMIT;
