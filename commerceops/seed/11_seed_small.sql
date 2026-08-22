-- =====================================================================
-- CommerceOps · 11_seed_small.sql   (dataset v1, profile: small)
--
-- Amac: Module 1-6 correctness calismasi. Hizli reset, hizli tam tarama.
-- Yaklasik hacim: ~12.000 order, ~24.000 order item.
--
-- Onkosul: schema.sql, 10_reference_data.sql calistirilmis olmali.
-- =====================================================================

SET search_path = commerceops, public;

SELECT co_generate('small');

INSERT INTO dataset_info (id, dataset_version, profile, generated_at, notes)
VALUES (1, 'v1', 'small', now(),
        'Correctness profile. Module 1-6 icin. Deterministic generator, sabit referans tarih 2026-08-20.')
ON CONFLICT (id) DO UPDATE
SET dataset_version = EXCLUDED.dataset_version,
    profile         = EXCLUDED.profile,
    generated_at    = EXCLUDED.generated_at,
    notes           = EXCLUDED.notes;

SELECT profile, dataset_version, generated_at FROM dataset_info;
