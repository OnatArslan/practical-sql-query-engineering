# Kurulum ve Reset Rehberi

## 0. Readiness gate

Module 1'e baslamadan once bu bes maddenin hepsi saglanmali:

- [ ] PostgreSQL container calisiyor
- [ ] Schema yuklu (`commerceops` schema'sinda 17 business tablosu)
- [ ] `small` seed profile yuklu
- [ ] `14_verify_seed.sql` hatasiz gecti ("Seed dogrulama basarili")
- [ ] IntelliJ data source dogru database'e bagli ve `commerceops` schema'si gorunuyor

---

## 1. Container

```bash
docker compose up -d
docker compose ps          # healthy olmasini bekle
```

Baglanti bilgileri (`compose.yaml`):

```text
host     localhost
port     5433              # 5432 degil: yerel PostgreSQL ile catismasin
database commerceops
user     commerceops_app
password commerceops_dev
```

---

## 2. Ilk kurulum (small profile)

Sirasi onemlidir:

```bash
cd commerceops
export PGPASSWORD=commerceops_dev
PSQL="psql -h localhost -p 5433 -U commerceops_app -d commerceops -v ON_ERROR_STOP=1"

$PSQL -f schema/schema.sql
$PSQL -f seed/10_reference_data.sql
$PSQL -f seed/11_seed_small.sql
$PSQL -f seed/14_verify_seed.sql
$PSQL -f seed/15_analyze.sql
```

Tek satirda:

```bash
for f in schema/schema.sql \
         seed/10_reference_data.sql seed/11_seed_small.sql \
         seed/14_verify_seed.sql seed/15_analyze.sql; do
  $PSQL -f "$f" || break
done
```

`schema.sql` schema'yi **DROP** eder; yeniden kurulum her zaman temiz baslar.

---

## 3. Hizli reset (schema'yi bozmadan)

Veriyi yeniden uretmek icin schema'yi tekrar kurmaya gerek yok:

```sql
SELECT commerceops.co_generate('small');
```

Generator once ilgili tablolari `TRUNCATE ... RESTART IDENTITY` eder, sonra yeniden
uretir. `categories` reference data'dir ve korunur. Sonrasinda:

```bash
$PSQL -f seed/14_verify_seed.sql
$PSQL -f seed/15_analyze.sql
```

Mutation calismalarindan (Module 7) sonra **her zaman** bu resetle temiz duruma don.

---

## 4. Profil degistirme

Module 9'a gecmeden once:

```bash
$PSQL -f seed/12_seed_full.sql     # ~1-2 dakika surer
$PSQL -f seed/14_verify_seed.sql
$PSQL -f seed/15_analyze.sql       # ZORUNLU: planner istatistikleri
```

Hangi profilin yuklu oldugunu her zaman kontrol edebilirsin:

```sql
SELECT profile, dataset_version, generated_at FROM commerceops.dataset_info;
```

`full` profilde geri donmek icin `11_seed_small.sql` yeterlidir.

---

## 5. Anomaly lab

```sql
-- yukle (idempotent, tekrar calistirilabilir)
\i seed/13_edge_cases.sql

-- ne yuklendi?
SELECT lab_case, table_name, row_id, note FROM commerceops.lab_objects ORDER BY lab_case;

-- temizle
SELECT commerceops.lab_reset();
```

Lab kayitlari `14_verify_seed.sql` dogrulamasindan haric tutulur; yuklu olsalar bile
verification PASS verir.

---

## 6. Mutation calismasi icin guvenli yontem

Module 7'de veri degistiren query yazacaksin. Uc kural:

1. `full` profil **mutation lab'i olarak kullanilmaz**. Once `small`'a don.
2. Denemeleri transaction icinde yap:

   ```sql
   BEGIN;
   UPDATE commerceops.products SET status = 'ARCHIVED' WHERE id = 42;
   SELECT * FROM commerceops.products WHERE id = 42;
   ROLLBACK;   -- sonucu gordun, degisikligi geri al
   ```
3. Kalici bir sey bozarsan: `SELECT commerceops.co_generate('small');`

---

## 7. IntelliJ Database Tool Window

1. **Database** panel → `+` → **Data Source** → **PostgreSQL**
2. Host `localhost`, Port `5433`, Database `commerceops`,
   User `commerceops_app`, Password `commerceops_dev`
3. **Test Connection** → **Apply**
4. Data source'a sag tikla → **Tools → Manage Shown Schemas** → `commerceops` isaretli olsun
5. Query console ac (`Ctrl/Cmd + Shift + Q`) ve dogrula:

```sql
SELECT current_database(), current_schema(), current_user;
SELECT profile, dataset_version FROM commerceops.dataset_info;
```

Kalici query'lerini `queries/` altindaki dosyalara yaz; query console'u kisa denemeler
icin kullan. Console'daki bir query kaybolursa geri gelmez.

### `search_path` notu

Tablolar `public` degil `commerceops` schema'sinda. Iki secenegin var:

```sql
-- (a) her seferinde qualified isim
SELECT count(*) FROM commerceops.orders;

-- (b) session icin search_path ayarla (her yeni console'da tekrar gerekir)
SET search_path = commerceops, public;
SELECT count(*) FROM orders;
```

Kurs dosyalarinda (b) tercih edilir; her `.sql` dosyasinin basinda `SET search_path`
satiri bulunur.

---

## 8. Sik karsilasilan sorunlar

| Belirti | Sebep | Cozum |
|---|---|---|
| `relation "orders" does not exist` | `search_path` ayarlanmamis | `SET search_path = commerceops, public;` |
| `function co_generate(...) does not exist` | `10_reference_data.sql` calistirilmamis | Dosyayi yukle |
| Verification FAIL veriyor | Seed yarim kalmis veya elle veri degistirilmis | `SELECT commerceops.co_generate('small');` ile reset |
| `EXPLAIN` tahminleri sacma | `ANALYZE` calistirilmamis | `seed/15_analyze.sql` |
| Port 5432 dolu | Yerel PostgreSQL calisiyor | compose 5433 kullanir; data source portunu kontrol et |
