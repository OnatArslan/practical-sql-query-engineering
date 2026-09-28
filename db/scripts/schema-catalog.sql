-- Canonical PostgreSQL 17 catalog contract; refresh deliberately after schema review.
COPY (
    SELECT 'constraint' AS kind, t.relname||'.'||c.conname AS name, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid WHERE c.connamespace='public'::regnamespace
    UNION ALL
    SELECT 'index',tablename||'.'||indexname,indexdef FROM pg_indexes WHERE schemaname='public'
    ORDER BY 1,2
) TO STDOUT WITH CSV HEADER;
