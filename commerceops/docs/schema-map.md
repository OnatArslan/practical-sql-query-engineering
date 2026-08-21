# CommerceOps Schema Map — dataset v1

Bu dosya kurs boyunca **join path** ve **cardinality** tartismalarinin referansidir.
Query yazmadan once buraya bak: join path data type benzerliginden degil, bu haritadan cikar.

Tum tablolar `commerceops` schema'sindadir (`public` degil).

---

## 1. Tablo rolleri

Bir tablonun rolu, o tabloyu query'nin **root/grain** tablosu secip secmeyecegini belirler.

| Rol | Tablolar | Anlami |
|---|---|---|
| Entity / master | `users`, `merchants`, `products`, `categories`, `warehouses`, `addresses` | Bagimsiz varlik. Genelde parent tarafinda durur. |
| Transaction / fact | `orders`, `order_items`, `payments`, `refunds`, `shipments`, `shipment_items`, `inventory_movements` | Is olayinin sonucu. Cogu raporun grain'i burasidir. |
| Event / history | `order_status_history` | Zaman serisi. Ayni parent icin cok satir; "latest row" problemi buradan cikar. |
| Junction | `product_categories`, `merchant_members`, `shipment_items` | Many-to-many. Kendi attribute'larini da tasiyabilir. |
| Feedback | `reviews` | Opsiyonel child; cogu urunde yok. |
| Meta | `dataset_info`, `lab_objects` | Dataset yonetimi. Business query'lerde kullanilmaz. |

`shipment_items` hem junction hem fact'tir: `shipments` ile `order_items` arasindaki
many-to-many'yi kurar ve uzerinde `quantity` tasir.

---

## 2. Relationship map

```text
users ──< addresses
users ──< orders ──< order_items >── products >── merchants
users ──< merchant_members >── merchants
merchants ──< products ──< product_categories >── categories ──< categories (parent_id)
merchants ──< warehouses ──< inventory_movements >── products
orders ──< order_status_history
orders ──< payments ──< refunds
orders ──< shipments ──< shipment_items >── order_items
users ──< reviews >── products
refunds >── order_items        (nullable: order-level refund ise NULL)
orders  >── addresses          (nullable: shipping_address_id)
shipments >── warehouses       (nullable)
reviews >── order_items        (nullable)
```

`──<` : one-to-many (sol taraf parent)
`>──` : many-to-one (sol taraf child)

---

## 3. Kritik cardinality notlari

Bunlar row multiplication ve aggregate inflation hatalarinin kaynagidir:

| Iliski | Cardinality | Sonuc |
|---|---|---|
| `orders → order_items` | 1 : 1..4 | Order listesine item join edilirse order satiri tekrarlanir. |
| `orders → payments` | 1 : 0..3 | Basarisiz denemeler dahil. Payment join'i order'i cogaltir. |
| `orders → shipments` | 1 : 0..2 | Split shipment. |
| `orders → order_status_history` | 1 : 1..5 | En yogun cogaltici. |
| `order_items → shipment_items` | 1 : 0..2 | Kismi ve bolunmus gonderim. |
| `payments → refunds` | 1 : 0..2 | Partial refund. |
| `products → product_categories` | 1 : 0..3 | Kategori join'i urun satirini cogaltir. |
| `users → merchant_members` | 1 : 0..N | Bir user birden fazla merchant'in uyesi olabilir. |
| `merchants → warehouses` | 1 : 0..3 | Bazi merchant'larin hic deposu yok. |
| `products → inventory_movements` | 1 : 0..N | En kalabalik child. |

**Iki bagimsiz child'i ayni anda join etmek carpim uretir:**

```text
order_item_count × payment_attempt_count = naive joined row count
```

Bu carpim JOIN condition dogru olsa bile olusur. Cozum `DISTINCT` degil,
metric'i kendi grain'inde ayri hesaplamaktir.

---

## 4. Merchant iliskisinin ozel durumu

`orders` tablosunda `merchant_id` **yoktur**. Bir order birden fazla merchant'in
item'ini icerebilir. Dolayisiyla:

- "Bu merchant'in order'lari" = `order_items.merchant_id` uzerinden **existence**
- "Bu merchant'in bu order'daki cirosu" = sadece o merchant'a ait item'larin toplami
- Merchant order listesinde order total ile merchant subtotal **ayri iki metriktir**

Bu ayrim Module 8'deki `GET /merchants/{merchantId}/orders` endpoint'inin merkezidir.

---

## 5. Query interpretation rules (sabit business anlamlari)

1. Order toplami `order_items.quantity * unit_price - discount_amount` uzerinden hesaplanir.
   `products.price` **guncel** fiyattir, tarihsel hesapta kullanilmaz.
2. Revenue yalnizca `payments.status = 'SUCCEEDED'` kayitlarindan hesaplanir.
3. Net revenue = gross - `refunds` (status = 'COMPLETED'). Gross ile karistirilmaz.
4. Cancelled order'larin dahil/haric olmasi her requirement'ta ayrica belirtilir.
5. Shipment tamamlanmasi: her order item icin `SUM(shipment_items.quantity) = order_items.quantity`.
6. Inventory on-hand = `SUM(inventory_movements.quantity)` (isaretli toplam).
7. Merchant authorization = aktif `merchant_members` kaydi + gereken rol.
8. Category sorgularinda "dogrudan kategori" ile "descendant kategoriler" farki korunur.
9. Order'in adres bilgisi `orders.ship_*` snapshot'idir; `addresses` degisse bile degismez.

Bu kurallar query yazarken varsayilmaz; her gorev requirement'inda gereken kural acikca belirtilir.
