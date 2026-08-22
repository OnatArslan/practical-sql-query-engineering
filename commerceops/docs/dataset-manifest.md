# CommerceOps Dataset Manifest

| Alan | Deger |
|---|---|
| Dataset version | **v1** |
| Profiller | `small`, `full` |
| Uretildigi PostgreSQL | 18 hedef; 16+ ile uyumlu (surume ozgu syntax kullanilmadi) |
| Schema | `commerceops` |
| Order tarih araligi | 2025-01-01 … 2026-08-17 |
| Sabit referans tarih | **2026-08-20** (`d_ref`) |
| Uretim yontemi | Set-based generator (`co_generate(profile)`), elle yazilmis INSERT yigini yok |

Expected result'lar bu version'a gore hazirlanir. **Version degisirse tum beklenen
sonuclar yeniden dogrulanir.**

---

## 1. Profiller

| Profil | Amac | Uretim suresi | DB boyutu |
|---|---|---|---|
| `small` | Module 1–7 correctness calismasi, hizli reset | ~5 sn | ~37 MB |
| `full` | Module 8–9: pagination, search, index, execution plan | ~1 dk 40 sn | ~894 MB |

Sureler referans bir Linux container'da olculmustur; kendi makinende farklilik normaldir.

### Row counts

| Tablo | `small` | `full` |
|---|---:|---:|
| users | 3.000 | 120.000 |
| addresses | 4.499 | 180.004 |
| merchants | 40 | 400 |
| merchant_members | 141 | 1.402 |
| categories | 79 | 79 |
| products | 2.000 | 40.000 |
| product_categories | 3.883 | 77.600 |
| warehouses | 67 | 688 |
| orders | 12.000 | 400.000 |
| order_items | 20.519 | 684.012 |
| order_status_history | 52.990 | 1.766.885 |
| payments | 14.884 | 495.966 |
| refunds | 1.114 | 37.996 |
| shipments | 12.016 | 401.053 |
| shipment_items | 16.108 | 539.158 |
| inventory_movements | 17.712 | 546.524 |
| reviews | 3.730 | 124.335 |

`categories` reference data'dir ve iki profilde de aynidir.

---

## 2. Determinism sozlesmesi

- Unseeded `random()` **kullanilmaz**. Tum degiskenlik `co_hash(id, salt)` ile
  satirin kendi id'sinden turetilir.
- Zaman hesaplari `now()` yerine sabit `d_ref = 2026-08-20` referansini kullanir;
  boylece seed'i alti ay sonra calistirsan da ayni status dagilimi cikar.
- Ayni `profile` + ayni `dataset_version` → ayni business sonuclari.
- Entity id'leri (`users`, `merchants`, `products`, `orders`) explicit verilir ve stabildir.
  Child tablo id'leri insert sirasina bagli olarak stabildir (`ORDER BY` ile sabitlenmistir).
- Reference kayitlar (`categories`) ile bulk-generated fact kayitlari ayri dosyalardadir.
- Bu seed bir egitim dataset'idir; production migration zincirine sokulmaz.

---

## 3. Gercekci dagilim ozellikleri

Bunlar tesadufi degil, kasitli olarak uretilmistir:

- **Skewed satis**: az sayida populer urun satislarin cogunu alir (power-law).
- **Zero-child parent**: 1.200 user hic siparis vermemis, 264 ACTIVE urun hic satilmamis,
  6 merchant'in hic urunu yok, 815 urunun hic review'i yok (small profil rakamlari).
- **Buyume trendi**: siparis hacmi donem sonuna dogru artar; pazar gunleri daha dusuktur.
- **Multi-merchant order**: order'larin ~%47'si birden fazla merchant'in item'ini icerir.
- **Coklu payment attempt**: ~2.700 order'da once FAILED sonra SUCCEEDED attempt var.
- **Payment'siz order**: 328 order'in hic payment kaydi yok.
- **Refund**: hem partial hem full refund mevcut; bazi refund'lar `PENDING`
  (dolayisiyla `processed_at` NULL).
- **Split shipment**: 2.100 order birden fazla shipment'a bolunmus.
- **Kismi gonderim**: 1.329 order item eksik gonderilmis veya hic gonderilmemis.
- **Ayni timestamp**: 332 farkli `placed_at` degeri birden fazla order tarafindan
  paylasilir (full profilde 117.299 grup, en kalabalik grupta 153 order) →
  keyset pagination tie-breaker calismasi.
- **Fiyat kaymasi**: urunlerin ~%40'inin guncel fiyati degistirilmistir; bu yuzden
  `order_items.unit_price` ile `products.price` bilincli olarak farklidir.
- **Kontrollu NULL orani**: `users.phone`, `shipments.tracking_code`,
  `shipments.delivered_at`, `refunds.reason`, `products.description`,
  `payments.provider_response`, `orders.customer_note` alanlarinda NULL bulunur.
- **JSONB**: `payments.provider_response` (card, risk_score, flags) ve
  `inventory_movements.metadata` (reason, counted_by, approved).

---

## 4. Edge-case politikasi

**Tur 1 — valid but tricky (ana dataset icinde):** NULL degerler, zero-child parent,
ayni timestamp, coklu payment attempt, partial refund, split shipment, kismi gonderim.
Bunlar yasal veridir ve `14_verify_seed.sql` tarafindan **varliklari zorunlu tutulur**.

**Tur 2 — controlled anomaly lab (`13_edge_cases.sql`, ayri yuklenir):**
constraint ihlal etmeyen ama business kurali ihlal eden kayitlar.

| Case | Anomali | Ne ogretiyor |
|---|---|---|
| LAB-01 | Order item'dan fazla quantity gonderilmis | Shipment completion kontrolu iki yonlu olmali |
| LAB-02 | Refund toplami payment tutarini asiyor | Gross/net revenue reconciliation |
| LAB-03 | DELIVERED order'in basarili odemesi yok | Fulfillment vs revenue raporu farki |
| LAB-04 | `is_active = true` ama `ended_at` gecmiste | Authorization leakage |
| LAB-05 | Karsiligi olmayan OUTBOUND hareketi | Negatif on-hand, inventory reconciliation |
| LAB-06 | Bozuk status history (ters sira, ayni timestamp) | Latest-row query'sinde tie-breaker |
| LAB-07 | Hic item'i olmayan order | INNER JOIN ile kayip satir, total 0 mi NULL mu |
| LAB-08 | Payment order'dan once settle olmus | Rapor hangi timestamp'e gore uretiliyor |
| LAB-09 | Satin alinmamis urune `is_verified` review | Flag'e degil iliskiye guven |

Lab kayitlari `lab_objects` tablosuna yazilir. Temizlemek icin:
`SELECT commerceops.lab_reset();`

---

## 5. Baseline index politikasi

`schema.sql` icindeki baseline index seti **bilincli olarak eksiktir**. Child tablolarin FK
kolonlarinda index vardir; su alanlar Module 9'da olcumle degerlendirilmek uzere
bos birakilmistir:

`order_items(merchant_id)`, `orders(placed_at)`, `orders(status)`,
`payments(status, settled_at)`, `products(name)` / trigram, JSONB GIN,
keyset pagination composite index.

> Index kullanildigi icin query'nin otomatik iyi oldugu varsayilmaz.
> Index onerisi `full` profil uzerinde `EXPLAIN ANALYZE` olcumu olmadan yapilmaz.
