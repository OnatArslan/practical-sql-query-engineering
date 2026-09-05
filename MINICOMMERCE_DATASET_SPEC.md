# MiniCommerce Dataset & Codex Setup Spec

Bu dosya SQL Query Engineering kursuna başlamadan önce Codex'in hazırlayacağı local workspace'in sözleşmesidir.

## 1. Amaç

Kurs sırasında schema veya seed yazılmayacak. Öğrenci Lesson §1'e geldiğinde:

- PostgreSQL 17 çalışıyor,
- schema tamamen kurulmuş,
- `small` deterministic dataset restore edilmiş,
- `full` performance dataset hazır,
- schema/data dokümantasyonu repo içinde mevcut

olmalıdır.

## 2. Repo yapısı

```text
sql-query-engineering/
├── compose.yaml
├── db/
│   ├── schema/
│   │   ├── 00_schema.sql
│   │   ├── 01_constraints.sql
│   │   └── 02_indexes.sql
│   ├── seed/
│   │   ├── small.dump
│   │   ├── full.dump
│   │   └── edge_cases.sql
│   └── scripts/
│       ├── reset-small.sh
│       ├── reset-full.sh
│       └── verify-dataset.sh
├── docs/
│   ├── SCHEMA_MAP.md
│   ├── DATA_DICTIONARY.md
│   └── DATASET_MANIFEST.md
└── queries/
    ├── 01_foundations.sql
    ├── 02_joins.sql
    ├── 03_aggregation.sql
    ├── 04_subqueries_exists_ctes.sql
    ├── 05_windows.sql
    ├── 06_mutations.sql
    ├── 07_backend_queries.sql
    └── 08_performance.sql
```

## 3. PostgreSQL

Docker image:

```text
postgres:17
```

Database:

```text
minicommerce
```

Locale/timezone davranışı deterministic tutulmalı. Timestamp verileri UTC referanslı üretilmeli.

## 4. Schema

### customers

```text
id          bigint PK
email       varchar unique not null
name        varchar not null
created_at  timestamptz not null
```

### categories

```text
id          bigint PK
parent_id   bigint nullable FK -> categories.id
name        varchar not null
```

`parent_id` recursive CTE için 2–4 seviyeli gerçek hierarchy oluşturmalı.

### products

```text
id           bigint PK
category_id  bigint not null FK
name         varchar not null
price        numeric(12,2) not null
active       boolean not null
created_at   timestamptz not null
```

### orders

```text
id           bigint PK
customer_id  bigint not null FK
status       varchar not null
created_at   timestamptz not null
```

Allowed status:

```text
PENDING
PAID
SHIPPED
COMPLETED
CANCELLED
```

### order_items

```text
id          bigint PK
order_id    bigint not null FK
product_id  bigint not null FK
quantity    integer not null
unit_price  numeric(12,2) not null
```

`unit_price`, historical sale price'dır; current `products.price` ile eşit olmak zorunda değildir.

### payments

```text
id          bigint PK
order_id    bigint not null FK
status      varchar not null
amount      numeric(12,2) not null
provider    varchar not null
created_at  timestamptz not null
```

Allowed status:

```text
PENDING
SUCCEEDED
FAILED
REFUNDED
```

Bazı order'larda birden fazla payment attempt bulunmalıdır.

### shipments

```text
id            bigint PK
order_id      bigint not null unique FK
status        varchar not null
shipped_at    timestamptz nullable
delivered_at  timestamptz nullable
```

Bazı order'larda shipment olmamalıdır.

### order_status_history

```text
id          bigint PK
order_id    bigint not null FK
status      varchar not null
changed_at  timestamptz not null
```

Her order için zaman sıralı status history üret.

### inventory_movements

```text
id              bigint PK
product_id      bigint not null FK
quantity_delta  integer not null
reason          varchar not null
created_at      timestamptz not null
```

Positive/negative movement'lar running balance gösterecek biçimde üretilmeli.

## 5. Constraints ve indexes

Schema production-quality olmalı ancak query course'unu index-design kursuna çevirmemeli.

En az:

- PK/FK
- unique email
- positive quantity
- non-negative price/payment amount
- status CHECK constraints
- sensible FK indexes
- orders `(customer_id, created_at, id)` gibi gerçek query pattern'lerine hizmet eden makul indexes
- performance lesson'ında karşılaştırma için bazı query pattern'lerinde intentionally non-perfect index coverage

bulunmalı.

Index listesi ve gerekçesi `SCHEMA_MAP.md` içinde kısa yazılmalı.

## 6. Deterministic data

Seed random görünebilir ama fixed seed/version ile deterministic olmalıdır.

Version:

```text
minicommerce-v1
```

`DATASET_MANIFEST.md` içinde:

- exact row counts
- date range
- fixed random seed/version
- known edge cases
- önemli practice query'ler için gerektiğinde expected facts

yazılmalı.

## 7. Small dataset hedefi

Yaklaşık:

```text
customers               2,000
categories                 40
products                   500
orders                  15,000
order_items              45,000
payments                 18,000
shipments                11,000
order_status_history     60,000
inventory_movements      40,000
```

Exact counts deterministic olabilir; yaklaşık hedefe uyması yeterli.

## 8. Full dataset hedefi

Yaklaşık:

```text
customers               50,000
categories                 40
products                10,000
orders                 300,000
order_items            900,000
payments               360,000
shipments              220,000+
order_status_history 1,200,000
inventory_movements    600,000
```

Restore süresi makul olmalı.

## 9. Zorunlu edge cases

Dataset'te kesin bulunmalı:

- zero-order customer
- high-volume customer
- unsold product
- inactive product
- order with one payment
- order with multiple payment attempts
- failed-only payment order
- successful-after-failed payment order
- order without shipment
- delivered shipment
- cancelled order
- same timestamp'a sahip birden fazla order, pagination tie-breaker için
- category hierarchy
- product with many inventory movements
- product with very few movements
- inventory movement net total sıfır/pozitif/negatife yakın örnekleri

## 10. Verification

`verify-dataset.sh` en az şunları kontrol etsin:

- tüm tablolar mevcut
- exact row counts manifest ile uyumlu
- FK orphan yok
- edge case'ler gerçekten mevcut
- category recursion cycle yok
- aynı timestamp pagination edge case mevcut
- multiple payment-attempt order mevcut
- unsold product mevcut

Verification başarısızsa exit code non-zero.

## 11. ChatGPT Project'e taşınacak dokümanlar

Dump dosyalarını ChatGPT Project Source'a yüklemek gerekmez.

Project'e yüklenmesi faydalı:

```text
SCHEMA_MAP.md
DATA_DICTIONARY.md
DATASET_MANIFEST.md
```

Büyük `.dump` dosyaları local repo'da kalır.
