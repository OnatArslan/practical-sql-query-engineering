-- 01_foundations.sql
-- Practical SQL Query Engineering
--
-- Her query icin sablon:
--   -- [modul.mesaj] Requirement: ...
--   -- Result grain: bir satir = ...
--   -- Beklenen row behavior: ...
--   <query>
--   -- Dogrulama: <row count / karsilastirma query'si>

SET search_path = commerceops, public;

select * from commerceops.users;