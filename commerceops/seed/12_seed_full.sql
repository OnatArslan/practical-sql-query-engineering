-- =====================================================================
-- CommerceOps · 12_seed_full.sql   (dataset v1, profile: full)
--
-- Amac: Module 8-9 calismasi -> pagination, search, index, execution plan.
-- Yaklasik hacim: ~400.000 order, ~800.000 order item, ~1.5M inventory movement.
-- Uretim suresi makinene gore birkac dakika surebilir.
--
-- Onkosul: 00_schema.sql, 01_constraints.sql, 02_indexes_baseline.sql,
--          10_reference_data.sql calistirilmis olmali.
-- Sonrasi:  14_verify_seed.sql ve 15_analyze.sql MUTLAKA calistirilir.
-- =====================================================================

SET search_path = commerceops, public;

SELECT co_generate('full');

INSERT INTO dataset_info (id, dataset_version, profile, generated_at, notes)
VALUES (1, 'v1', 'full', now(),
        'Performance profile. Module 8-9 icin. Yukleme sonrasi 15_analyze.sql calistir.')
ON CONFLICT (id) DO UPDATE
SET dataset_version = EXCLUDED.dataset_version,
    profile         = EXCLUDED.profile,
    generated_at    = EXCLUDED.generated_at,
    notes           = EXCLUDED.notes;

SELECT profile, dataset_version, generated_at FROM dataset_info;
