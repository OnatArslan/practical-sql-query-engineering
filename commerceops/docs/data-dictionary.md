# CommerceOps Data Dictionary — dataset v1

Her tablo icin: **Grain** (bir satir neyi temsil eder) ve **Dikkat** (query yazarken
kritik olan business kurali). Kolon listesi `information_schema` uzerinden uretilmistir.

> Kural: query yazmadan once o query'nin **result grain**'ini bu tablodaki grain
> tanimlariyla karsilastir. Cogu duplicate-row hatasi burada baslar.

## `users`

**Grain:** Bir satir = bir sistem kullanicisi.

**Dikkat:** Customer ve merchant calisani ayni tabloda. `status` ACTIVE/SUSPENDED/DELETED; DELETED satir hala FK hedefi olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `email` | text | no |  |
| `full_name` | text | no |  |
| `phone` | text | YES |  |
| `status` | text | no | 'ACTIVE' |
| `created_at` | timestamptz | no | now() |
| `last_login_at` | timestamptz | YES |  |

## `addresses`

**Grain:** Bir satir = user'in kayitli bir adresi.

**Dikkat:** Order'in teslimat bilgisi buradan DEGIL, `orders.ship_*` snapshot kolonlarindan okunur.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `user_id` | bigint | no |  |
| `label` | text | no |  |
| `recipient_name` | text | no |  |
| `line1` | text | no |  |
| `line2` | text | YES |  |
| `city` | text | no |  |
| `postal_code` | text | YES |  |
| `country_code` | char(2) | no | 'TR' |
| `is_default` | boolean | no | false |
| `created_at` | timestamptz | no | now() |

## `merchants`

**Grain:** Bir satir = bir satici isletme.

**Dikkat:** Merchant ile order arasinda DOGRUDAN FK YOKTUR. Iliski `order_items.merchant_id` uzerinden kurulur.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `name` | text | no |  |
| `slug` | text | no |  |
| `status` | text | no | 'ACTIVE' |
| `commission_rate` | numeric(5,4) | no | 0.1000 |
| `country_code` | char(2) | no | 'TR' |
| `created_at` | timestamptz | no | now() |

## `merchant_members`

**Grain:** Bir satir = bir user'in bir merchant'taki uyeligi.

**Dikkat:** Authorization'in kaynagi. `is_active` VE rol birlikte degerlendirilir; `ended_at` dolu olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `merchant_id` | bigint | no |  |
| `user_id` | bigint | no |  |
| `role` | text | no |  |
| `is_active` | boolean | no | true |
| `joined_at` | timestamptz | no |  |
| `ended_at` | timestamptz | YES |  |

## `categories`

**Grain:** Bir satir = bir kategori.

**Dikkat:** `parent_id` self-reference. 4 seviyeye kadar derinlik var. Bazi leaf kategorilerde hic urun yok.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `parent_id` | bigint | YES |  |
| `name` | text | no |  |
| `slug` | text | no |  |
| `is_active` | boolean | no | true |
| `created_at` | timestamptz | no | now() |

## `products`

**Grain:** Bir satir = bir merchant'a ait bir urun.

**Dikkat:** `price` GUNCEL fiyattir. Tarihsel hesaplarda kullanilmaz; `order_items.unit_price` kullanilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `merchant_id` | bigint | no |  |
| `sku` | text | no |  |
| `name` | text | no |  |
| `description` | text | YES |  |
| `status` | text | no | 'ACTIVE' |
| `price` | numeric(12,2) | no |  |
| `currency` | char(3) | no | 'TRY' |
| `track_inventory` | boolean | no | true |
| `weight_grams` | integer | YES |  |
| `created_at` | timestamptz | no | now() |
| `updated_at` | timestamptz | no | now() |

## `product_categories`

**Grain:** Bir satir = product-category eslesmesi.

**Dikkat:** Many-to-many junction. `is_primary` tasidigi icin salt teknik ara tablo degildir. Bazi urunlerin hic kategorisi yok.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `product_id` | bigint | no |  |
| `category_id` | bigint | no |  |
| `is_primary` | boolean | no | false |
| `assigned_at` | timestamptz | no | now() |

## `orders`

**Grain:** Bir satir = bir marketplace siparisi.

**Dikkat:** TOTAL KOLONU YOKTUR; toplam order_items'tan hesaplanir. Bir order birden fazla merchant'in item'ini icerebilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `order_number` | text | no |  |
| `customer_id` | bigint | no |  |
| `status` | text | no |  |
| `currency` | char(3) | no | 'TRY' |
| `placed_at` | timestamptz | no |  |
| `created_at` | timestamptz | no |  |
| `updated_at` | timestamptz | no |  |
| `shipping_address_id` | bigint | YES |  |
| `ship_recipient_name` | text | no |  |
| `ship_line1` | text | no |  |
| `ship_city` | text | no |  |
| `ship_postal_code` | text | YES |  |
| `ship_country_code` | char(2) | no |  |
| `customer_note` | text | YES |  |

## `order_items`

**Grain:** Bir satir = siparisteki bir urun satiri (order + product).

**Dikkat:** Merchant, quantity ve unit_price siparis anindaki degerlerdir. Line total = quantity * unit_price - discount_amount.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `order_id` | bigint | no |  |
| `product_id` | bigint | no |  |
| `merchant_id` | bigint | no |  |
| `quantity` | integer | no |  |
| `unit_price` | numeric(12,2) | no |  |
| `discount_amount` | numeric(12,2) | no | 0 |
| `created_at` | timestamptz | no |  |

## `order_status_history`

**Grain:** Bir satir = bir status degisimi.

**Dikkat:** Event tablosu. Ayni order icin cok satir. `changed_at` esitse deterministic tie-breaker gerekir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `order_id` | bigint | no |  |
| `from_status` | text | YES |  |
| `to_status` | text | no |  |
| `changed_at` | timestamptz | no |  |
| `changed_by_user_id` | bigint | YES |  |
| `note` | text | YES |  |

## `payments`

**Grain:** Bir satir = bir odeme denemesi (order + attempt_no).

**Dikkat:** Revenue SADECE status='SUCCEEDED' kayitlardan hesaplanir. Bir order'da once FAILED sonra SUCCEEDED attempt olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `order_id` | bigint | no |  |
| `provider` | text | no |  |
| `attempt_no` | integer | no |  |
| `status` | text | no |  |
| `amount` | numeric(12,2) | no |  |
| `currency` | char(3) | no | 'TRY' |
| `created_at` | timestamptz | no |  |
| `settled_at` | timestamptz | YES |  |
| `failure_code` | text | YES |  |
| `provider_response` | jsonb | YES |  |

## `refunds`

**Grain:** Bir satir = bir iade kaydi.

**Dikkat:** Bir payment'a birden fazla partial refund baglanabilir. `order_item_id` NULL ise order-level refund'dir. Net revenue = gross - COMPLETED refunds.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `payment_id` | bigint | no |  |
| `order_item_id` | bigint | YES |  |
| `amount` | numeric(12,2) | no |  |
| `reason` | text | YES |  |
| `status` | text | no | 'COMPLETED' |
| `created_at` | timestamptz | no |  |
| `processed_at` | timestamptz | YES |  |

## `warehouses`

**Grain:** Bir satir = merchant'in bir deposu.

**Dikkat:** Bazi merchant'larin hic deposu yok; bu durumda shipment.warehouse_id NULL olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `merchant_id` | bigint | no |  |
| `code` | text | no |  |
| `name` | text | no |  |
| `city` | text | no |  |
| `country_code` | char(2) | no | 'TR' |
| `is_active` | boolean | no | true |
| `created_at` | timestamptz | no | now() |

## `inventory_movements`

**Grain:** Bir satir = bir stok hareketi.

**Dikkat:** `quantity` ISARETLIDIR (giris +, cikis -). On-hand = SUM(quantity); ayri stok kolonu yoktur.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `warehouse_id` | bigint | no |  |
| `product_id` | bigint | no |  |
| `movement_type` | text | no |  |
| `quantity` | integer | no |  |
| `occurred_at` | timestamptz | no |  |
| `reference_type` | text | YES |  |
| `reference_id` | bigint | YES |  |
| `metadata` | jsonb | YES |  |
| `created_at` | timestamptz | no |  |

## `shipments`

**Grain:** Bir satir = bir gonderi.

**Dikkat:** Bir order birden fazla shipment'a bolunebilir. `delivered_at` ve `tracking_code` NULL olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `order_id` | bigint | no |  |
| `warehouse_id` | bigint | YES |  |
| `carrier` | text | no |  |
| `tracking_code` | text | YES |  |
| `status` | text | no |  |
| `shipped_at` | timestamptz | YES |  |
| `delivered_at` | timestamptz | YES |  |
| `created_at` | timestamptz | no |  |

## `shipment_items`

**Grain:** Bir satir = bir order item'in bir shipment'taki miktari.

**Dikkat:** Kismi gonderim mumkundur: SUM(quantity) < order_items.quantity olabilir; bazi item'lar hic gonderilmemis olabilir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `shipment_id` | bigint | no |  |
| `order_item_id` | bigint | no |  |
| `quantity` | integer | no |  |

## `reviews`

**Grain:** Bir satir = bir kullanicinin bir urune yorumu.

**Dikkat:** (product_id, user_id) unique. `submitted_at` bilincli olarak `timestamp WITHOUT time zone`; `created_at` ise `timestamptz`.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | bigint | no |  |
| `product_id` | bigint | no |  |
| `user_id` | bigint | no |  |
| `order_item_id` | bigint | YES |  |
| `rating` | integer | no |  |
| `title` | text | YES |  |
| `body` | text | YES |  |
| `is_verified` | boolean | no | true |
| `submitted_at` | timestamp | no |  |
| `created_at` | timestamptz | no |  |

## `dataset_info`

**Grain:** Tek satir: yuklu dataset profile/version.

**Dikkat:** Her seed calismasinda guncellenir.

| Kolon | Tip | Null | Default |
|---|---|---|---|
| `id` | integer | no | 1 |
| `dataset_version` | text | no |  |
| `profile` | text | no |  |
| `generated_at` | timestamptz | no |  |
| `notes` | text | YES |  |
