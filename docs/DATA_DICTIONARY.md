# MiniCommerce data dictionary

Sürüm `minicommerce-v1`. Tüm tarihler `timestamptz`, üretim ve varsayılan oturum
timezone'ı UTC; database encoding UTF8, locale C. Tutarlar aynı varsayımsal para
birimindedir; döviz, vergi, kargo ücreti ve ayrı refund business tablosu yoktur.
PK `id` kolonları identity'dir. Aşağıda `?` NULL kabul eder; diğerleri NOT NULL.

## customers

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| email | varchar(254) | UNIQUE, boş olamaz; sentetik `example.test` |
| name | varchar(200) | Müşteri görünen adı; boş olamaz |
| created_at | timestamptz | Kayıt tarihi; seed'de 2023 |

## categories

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| parent_id | bigint ? | FK categories.id; NULL kök; kendi id'si olamaz |
| name | varchar(120) | Kategori adı; boş olamaz |

Kökler 1–4: Electronics, Home, Clothing, Outdoors. 5–16 ikinci, 17–32 üçüncü,
33–40 dördüncü seviye. İsim için global uniqueness gerekmez.

## products

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| category_id | bigint | FK categories.id |
| name | varchar(200) | Ürün adı; boş olamaz |
| price | numeric(12,2) | Güncel liste fiyatı; sonlu ve >= 0 |
| active | boolean | Katalogda şu an aktif; geçmiş satışını silmez |
| created_at | timestamptz | Ürün oluşturma tarihi; seed'de 2023 |

## orders

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity; timestamp eşitliklerinde tie-breaker |
| customer_id | bigint | FK customers.id |
| status | varchar(20) | PENDING, PAID, SHIPPED, COMPLETED, CANCELLED |
| created_at | timestamptz | Sipariş tarihi; 2024, 30 dakikalık çözünürlük |

## order_items

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| order_id | bigint | FK orders.id |
| product_id | bigint | FK products.id |
| quantity | integer | > 0, seed'de 1–5 |
| unit_price | numeric(12,2) | Tarihsel satış birim fiyatı; sonlu ve >= 0 |

Satır tutarı `quantity * unit_price`; order toplamı satır tutarlarının toplamıdır.
Güncel `products.price` üzerinden geçmiş sipariş tutarı hesaplanmaz.

## payments

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| order_id | bigint | FK orders.id; unique değildir |
| status | varchar(20) | PENDING, SUCCEEDED, FAILED, REFUNDED |
| amount | numeric(12,2) | Attempt tutarı; sonlu ve >= 0 |
| provider | varchar(40) | Boş olmayan sağlayıcı; stripe, adyen, paypal |
| created_at | timestamptz | Attempt zamanı; siparişten 5 veya 10 dakika sonra |

Her kayıt bir attempt'in mevcut durumudur. REFUNDED, önceden başarılı olmuş ve
tamamen iade edilmiş attempt'i temsil eder; ayrı ek gelir değildir. FAILED/PENDING
tutarları tahsilat değildir. Seed'de her attempt tüm sipariş tutarını taşır; birden
fazla attempt tutarını toplamak sipariş tutarını çoğaltır. Pending ve cancelled
order'larda da payment kayıtları vardır.

## shipments

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| order_id | bigint | UNIQUE FK orders.id |
| status | varchar(20) | PENDING, SHIPPED, DELIVERED |
| shipped_at | timestamptz ? | PENDING'de NULL; diğer durumlarda dolu |
| delivered_at | timestamptz ? | Yalnız DELIVERED'de dolu, shipped_at'ten önce olamaz |

Başlangıç dataset'inde SHIPPED ve DELIVERED bulunur; PENDING schema tarafından
desteklenir. PENDING/PAID/CANCELLED order'larda shipment yoktur.

## order_status_history

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity |
| order_id | bigint | FK orders.id |
| status | varchar(20) | Orders ile aynı allowed status kümesi |
| changed_at | timestamptz | Status olayının UTC zamanı |

İlk olay order oluşturulurken PENDING. Retry kuyruğunda ek PENDING olayı olabilir;
ardışık aynı status geçerlidir. PAID +15 dakika, SHIPPED +1 gün, COMPLETED +3 gün,
CANCELLED +1 saat. Son olay order.status ile aynı; her order içinde zamanlar kesin
artan sıradadır. REFUNDED attempt'li iptallerin geçmişinde PAID bulunur.

## inventory_movements

| Kolon | Tip | Anlam / kural |
|---|---|---|
| id | bigint | PK, identity; timestamp tie-breaker |
| product_id | bigint | FK products.id |
| quantity_delta | integer | Sıfır olmayan işaretli stok değişimi |
| reason | varchar(30) | RESTOCK/RETURN pozitif, SALE negatif, ADJUSTMENT iki işaret de olabilir |
| created_at | timestamptz | Ledger olay zamanı; seed'de 2024 |

Ledger geçmişten alınmış bağımsız bir hareket örneklemidir; tüm order_items'ın
birebir stok muhasebesi değildir. Başlangıç bakiyesi ayrıca tutulmaz. Running
balance sırası `(created_at, id)` olur. Sıfır, pozitif ve -1 net örnekleri bilerek
vardır; net/running toplam için negatif olmama constraint'i konulmaz. Seed'de
RESTOCK, SALE, ADJUSTMENT bulunur; RETURN schema tarafından desteklenir.
