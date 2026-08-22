# Practical SQL Query Engineering with PostgreSQL

Java/Spring Boot backend gelistiricileri icin PostgreSQL query engineering calisma repo'su.
Merkez SQL syntax degil: **gercek backend requirement'ini dogru query'ye cevirmek**,
result set davranisini aciklamak, mantiksal hatalari fark etmek ve query'yi production
baglaminda degerlendirmek.

## Hizli baslangic

```bash
docker compose up -d

cd commerceops
export PGPASSWORD=commerceops_dev
PSQL="psql -h localhost -p 5433 -U commerceops_app -d commerceops -v ON_ERROR_STOP=1"

$PSQL -f schema/schema.sql
$PSQL -f seed/10_reference_data.sql
$PSQL -f seed/11_seed_small.sql
$PSQL -f seed/14_verify_seed.sql
$PSQL -f seed/15_analyze.sql
```

Beklenen son cikti: `NOTICE: Seed dogrulama basarili. Dataset kullanima hazir.`

Detay ve IntelliJ kurulumu: [`commerceops/docs/reset-guide.md`](commerceops/docs/reset-guide.md)

## Repo duzeni

```text
compose.yaml                     PostgreSQL 18 (port 5433)

commerceops/
  schema/   schema.sql            tablolar + FK/unique/check + BILINCLI OLARAK EKSIK
                                  baseline index; her tablonun constraint ve index'i
                                  kendi CREATE TABLE blogunun altinda
  seed/     10_reference_data.sql deterministic helper'lar + kategori agaci + generator
            11_seed_small.sql     small profile  (~12.000 order)
            12_seed_full.sql      full profile   (~400.000 order)
            13_edge_cases.sql     controlled anomaly lab (ayri, resetlenebilir)
            14_verify_seed.sql    structural + teaching property dogrulamasi
            15_analyze.sql        planner istatistikleri
  docs/     schema-map.md         join path, tablo rolleri, cardinality
            data-dictionary.md    kolon kolon referans + grain notlari
            dataset-manifest.md   version, profiller, row count, dagilim ozellikleri
            reset-guide.md        kurulum, reset, profil degistirme, IntelliJ
  queries/  01..09 + buggy_queries.sql   kalici query dosyalarin

integration/  generated_jpa_sql.sql, orm_review_notes.md   (Module 9.4)
notes/        ders notlarin
```

## Calisma kurallari

- Kalici query'ler `queries/` altindaki dosyalara yazilir; query console kisa denemeler icindir.
- Her onemli query icin row count ve ornek satirlar dogrulanir.
- Hangi dataset profile ve version ile calisildigi not edilir.
- `SELECT *` yalnizca kesif amaclidir.
- Index onerisi `full` profil uzerinde olcum olmadan yapilmaz.

> Query'nin calismasi dogru oldugu anlamina gelmez.
> Dogru row count, her kolon degerinin dogru oldugu anlamina gelmez.
> Index kullanilmasi query'nin otomatik olarak iyi oldugu anlamina gelmez.
# practical-sql-query-engineering
