# MiniCommerce dataset manifest

Kaynak sözleşme: `MINICOMMERCE_DATASET_SPEC.md`.
Version: **minicommerce-v1**. Fixed seed: **1729**.
Tek üretici: `db/seed/generate.sql`; ortak fixture: `db/seed/edge_cases.sql`.

## Exact row counts

| Table | small | full |
|---|---:|---:|
| customers | 2000 | 50000 |
| categories | 40 | 40 |
| products | 500 | 10000 |
| orders | 15000 | 300000 |
| order_items | 45000 | 900000 |
| payments | 18000 | 360000 |
| shipments | 11250 | 225000 |
| order_status_history | 52800 | 1056000 |
| inventory_movements | 40000 | 600000 |

Makine karşılığı `db/seed/expected-counts.csv`; verification hem bu tabloyla
doküman uyumunu hem gerçek DB sayılarını kontrol eder. History sayısı yaklaşık
hedefin altındadır: her order yalnız ulaştığı durumları ve varsa retry olayını
içerir; tamamlanmamış siparişlere sahte tamamlanma olayları eklenmez. Her iki
boyutta da aynı 3,52 history/order ortalaması vardır. Shipment oranı %75'tir.

## Determinizm ve tarihler

Hash: `md5('minicommerce-v1:1729:' || stream || ':' || id)` ilk sekiz hex hanesi
unsigned 32-bit integer'a çevrilir. Stream isimleri alanları birbirinden ayırır.
Hesaplamalar integer/numeric kullanır; `random()`, `now()`, local timezone,
thread sırası veya host PRNG davranışına bağımlılık yoktur. Tüm INSERT sıraları
ve identity sequence değerleri sabittir. small ve full yalnız customer/product/
order/movement ölçeği açısından farklıdır; small, full'ün birebir prefix'i değildir.

Database locale C, encoding UTF8, server ve üretim timezone'ı UTC.
Aşağıdaki aralıklar alt sınır dahil, üst sınır hariçtir:

| Alanlar | Üretim aralığı (UTC) |
|---|---|
| customers.created_at, products.created_at | 2023-01-01 00:00:00Z – 2024-01-01 00:00:00Z |
| orders.created_at | 2024-01-01 00:00:00Z – 2025-01-01 00:00:00Z |
| payments.created_at | Order tarihi +5 veya +10 dakika; 2024 içinde |
| shipments.shipped_at | Order tarihi +1 gün; 2024-01-02 – 2025-01-02 |
| shipments.delivered_at | Completed order tarihi +3 gün; 2024-01-04 – 2025-01-04 |
| order_status_history.changed_at | Order tarihi ile +3 gün arası; 2024-01-01 – 2025-01-04 |
| inventory_movements.created_at | 2024-01-01 00:00:00Z – 2025-01-01 00:00:00Z |

Tüm timestamp'lerin doğrulanan genel zarfı `[2023-01-01Z, 2025-01-04Z)`.
Tarih raporu: `db/scripts/dataset-facts.sql` gerçek min/max değerlerini verir.

Üretilen ve restore edilen veride gözlenen kesin sınırlar (tümü UTC):

| Kolon | small min | small max | full min | full max |
|---|---|---|---|---|
| customers.created_at | 2023-01-01 10:45:28 | 2023-12-31 23:17:48 | 2023-01-01 00:08:38 | 2023-12-31 23:24:40 |
| products.created_at | 2023-01-01 12:13:53 | 2023-12-31 23:25:26 | 2023-01-01 00:08:30 | 2023-12-31 23:25:26 |
| orders.created_at | 2024-01-01 04:00:00 | 2024-12-31 23:30:00 | 2024-01-01 00:00:00 | 2024-12-31 23:30:00 |
| payments.created_at | 2024-01-01 04:05:00 | 2024-12-31 23:40:00 | 2024-01-01 00:05:00 | 2024-12-31 23:40:00 |
| shipments.shipped_at | 2024-01-02 04:00:00 | 2025-01-01 23:30:00 | 2024-01-02 00:00:00 | 2025-01-01 23:30:00 |
| shipments.delivered_at | 2024-01-04 04:00:00 | 2025-01-03 23:30:00 | 2024-01-04 00:00:00 | 2025-01-03 23:30:00 |
| order_status_history.changed_at | 2024-01-01 04:00:00 | 2025-01-03 23:30:00 | 2024-01-01 00:00:00 | 2025-01-03 23:30:00 |
| inventory_movements.created_at | 2024-01-01 00:00:00 | 2024-12-31 23:59:27 | 2024-01-01 00:00:00 | 2024-12-31 23:59:27 |

`small.fingerprints.csv` ve `full.fingerprints.csv`, tablo bazında sıralı tüm
satır/kolon içeriklerinin MD5 özetleridir. Bunlar deterministik veri eşitliği
kontrolüdür; güvenlik imzası değildir. Her dump'ın yerel SHA-256 yan dosyası,
dosya hasarını restore öncesi yakalar. PostgreSQL custom dump başlıklarında
oluşturulma zamanı bulunabildiğinden mantıksal determinizm esas alınır.

## Dağılım ve beklenen sabit gerçekler

| Özellik | small | full |
|---|---:|---:|
| PENDING orders | 750 | 15000 |
| CANCELLED orders | 750 | 15000 |
| PAID orders | 2250 | 45000 |
| SHIPPED orders | 2250 | 45000 |
| COMPLETED orders | 9000 | 180000 |
| Tek payment attempt'li orders | 12000 | 240000 |
| İki payment attempt'li orders | 3000 | 60000 |
| FAILED-only orders | 450 | 9000 |
| FAILED ardından SUCCEEDED orders | 2700 | 54000 |
| REFUNDED payment attempts | 300 | 6000 |
| Shipment olmayan orders | 3750 | 75000 |
| DELIVERED shipments | 9000 | 180000 |
| Inactive products | 50 | 1000 |
| Zero-order customers (gerçek toplam) | 258 | 8140 |
| Unsold products (gerçek toplam) | 25 | 500 |
| Product 4 inventory movements | 9463 | 124895 |

Customer 1 her 20 order'dan birini ve sabit iki pagination fixture'ını alır:
small **752**, full **15002** order. Müşterilerin ilk %10'u toplam siparişlerin
%60'ından fazlasını alır. Son %10 müşteri kesinlikle zero-order'dır; hash nedeniyle
başka zero-order müşteriler de olabilir. Ürünlerin ilk %10'u item satırlarının
%70'inden fazlasını alır; son %5 ürün kesinlikle unsold'dur.

Siparişlerin yaklaşık %75'i Q4 2024'te yoğunlaşır. Fiyatlar düşük değerlere
eğilimli 5,00–1004,80 aralığında; satış fiyatı güncel fiyatın %80–110'u arasında,
iki ondalığa yuvarlanır. Siparişler 1–5 item satırı içerir, ortalama 3'tür;
quantity yaklaşık %80 olasılıkla 1, diğer durumda 2–5'tir. Provider dağılımı
yaklaşık %70 stripe, %20 adyen, %10 paypal. Katalog ağırlığı kategori 33–36'dadır.
Stok hareketleri ürün 4'te ve düşük ürün id'lerinde yoğunlaşır.

## Zorunlu edge-case referansları

| Edge case | Her iki profilde garanti edilen örnek / kural |
|---|---|
| Zero-order customer | En büyük customer id; son %10 müşteri |
| High-volume customer | customer_id=1 |
| Unsold product | En büyük product id; son %5 ürün |
| Inactive product | product_id=10; id % 10 = 0 |
| One payment | order_id=1 |
| Multiple payment attempts | order_id=10; id % 5 = 0 |
| Failed-only payment | order_id=5 |
| Successful-after-failed | order_id=10; +5 dakika FAILED, +10 dakika SUCCEEDED |
| Order without shipment | order_id=1 |
| Delivered shipment | order_id=40 |
| Cancelled order | order_id=5 |
| Same timestamp orders | order_id=1 ve 2, customer_id=1, 2024-12-01 12:00:00Z |
| Category hierarchy | 1 → 5 → 17 → 33; maksimum dört seviye, cycle yok |
| Many inventory movements | product_id=4, en az 1000 hareket |
| Very few movements | En büyük product id: tam bir RESTOCK (+25) |
| Net zero | product_id=1: +10, -10 = 0 |
| Net positive | product_id=2: +10, -9 = +1 |
| Near-zero negative net | product_id=3: +10, -11 = -1; son hareket ADJUSTMENT |

## Verification kapsamı

`verify-dataset.sh small|full [database]`: PostgreSQL sürümü, locale, tam dokuz
tablo, kolon tipleri/NULL/identity, sequence değerleri, 38 constraint
(9 PK, 9 FK, 2 UNIQUE, 18 CHECK), constraint/index tanımlarının
`db/schema/expected-catalog.csv` ile birebir uyumu, sekiz ek index, tüm FK orphan'ları, CHECK'e
aykırı satırlar, exact row count, yukarıdaki edge case'ler, kategori cycle,
payment/order tutarı, tarih sırası, latest history/status uyumu, tarih zarfı ve
skew assertion'ları. Ayrıca kanonik içerik fingerprint'leri karşılaştırılır.
Başarısız kontrol non-zero exit verir. Restore ve build bunu zorunlu kapı olarak kullanır.

`test-verification.sh` ayrı veritabanında 19 geçersiz yazmanın reddini, kategori
cycle'ının, bozulan ledger fixture'ının, aynı row count ile içerik değişikliğinin
ve kaldırılmış FK'nin verification'ı başarısız kıldığını kontrol eder.
