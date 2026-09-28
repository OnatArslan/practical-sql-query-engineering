# MiniCommerce kurulum doğrulaması

2026-09-05 tarihinde gerçek Docker/PostgreSQL üzerinde tamamlandı.

- PostgreSQL **17.10**, `postgres:17`; UTF8, locale C, timezone UTC.
- Image digest: `sha256:5c855ad7b85e68e48a62f34662853f38b57c1c1d80f3a927ab58034fd6d31c5e`.
- Container `minicommerce-postgres-1`: **healthy**, `127.0.0.1:5432`.
- Son durum: `minicommerce` üzerinde **small** dataset; geçici build/restore DB kalmadı.
- Dokuz tablo, 38 constraint ve 19 index doğrulandı. Exact row count'lar manifest ile aynı.
- Small ve full, temiz veritabanlarında yeniden üretildi; dokuz tablonun tüm
  satır/kolon fingerprint'leri her iki boyutta da önceki üretimle birebir aynı.
- Her dump öncesinde schema/dataset verification başarılı oldu.
- Full dump staging DB'ye restore edildi, verification ve fingerprint karşılaştırması
  geçti; ardından gerçek `minicommerce` DB olarak da doğrulandı. Small'a aynı yolla dönüldü.
- Zorunlu tüm edge case'ler, orphan/cycle yokluğu, kronoloji ve skew assertion'ları geçti.
- 19 geçersiz yazma beklenen SQLSTATE ile reddedildi. Dört kasıtlı bozulma
  (kategori cycle, eksik ledger edge case, aynı row count ile içerik değişimi,
  kaldırılmış FK) verification'da non-zero exit verdi.
- Yerel dump boyutları yaklaşık **1,7 MB small / 34 MB full**; restore edilmiş DB
  boyutları yaklaşık **32 MB / 427 MB**. SHA-256 arşiv kontrolleri geçti.
- `MINICOMMERCE_DATASET_SPEC.md` değiştirilmedi. Query dosyaları yalnız başlangıç
  yorumları içerir; lesson veya application code üretilmedi.

Çalıştırılan ana komutlar (tümü son çalıştırmada exit 0):

```bash
docker compose up -d --wait
db/scripts/build-datasets.sh small
db/scripts/build-datasets.sh full
db/scripts/build-datasets.sh
diff -u db/seed/small.fingerprints.csv .local/small.generated.csv
diff -u db/seed/full.fingerprints.csv .local/full.generated.csv
db/scripts/test-verification.sh
db/scripts/reset-full.sh
db/scripts/reset-small.sh
db/scripts/verify-dataset.sh small
docker compose ps
```

Yerel ayrıntılı çıktılar `.local/rebuild-determinism.log`,
`.local/test-verification.log`, `.local/restore-full.log`,
`.local/restore-small-final.log`, `.local/verify-final.log` ve
`.local/small-facts.txt` / `.local/full-facts.txt` içindedir. Bunlar Git'e eklenmez.

## 2026-09-20 — Paylaşılan spec ile yeniden üretim ve seed yükleme

`/Users/onatarslan/Downloads/MINICOMMERCE_DATASET_SPEC.md` tamamen okundu ve
repository'deki sözleşmeyle byte bazında aynı olduğu doğrulandı. İki dosyanın
SHA-256 değeri: `11ac741e1fbb23164aa5db8d87d71e114bd30bbda60433fe36dfb1d48c105572`.
Dolayısıyla paylaşılan dosyada yeni bir schema değişikliği bulunmadı.

- Yeni tek komut: `./db/scripts/seed.sh small`; iki dataset'i SQL kaynaklarından
  yeniden üretir ve seçilen profili yükler. Parametresiz kullanım `small`,
  `./db/scripts/seed.sh full` kullanımı sonunda yüklenecek profil `full` olur.
- Bu komut gerçek PostgreSQL üzerinde çalıştırıldı ve exit 0 döndü.
- Small ve full için schema, row count, FK, edge case, kronoloji, skew ve kanonik
  içerik fingerprint kontrolleri dump üretiminden önce geçti.
- Dokuz tablo, constraint'ler ve index'ler temiz build veritabanlarında yeniden
  oluşturuldu; small dump doğrulanıp çalışma veritabanına yüklendi.
- Yenilenen full dump ayrıca `minicommerce_restore_full` veritabanına restore
  edildi; tüm doğrulamalar geçti ve geçici veritabanı kaldırıldı.
- Son durum: sağlıklı PostgreSQL container, `localhost:5436`, database/user/password
  `minicommerce`; çalışma dataset'i **small**. 2.000 müşteri, 500 ürün, 15.000
  sipariş, 45.000 item satırı. Full dump'ta 300.000 sipariş ve 900.000 item satırı var.
- README bağlantı portu mevcut Compose ayarıyla uyumlu olacak şekilde düzeltildi.

Yerel işlem kayıtları: `.local/seed-rebuild-2026-09-20.log` ve
`.local/full-restore-check-2026-09-20.log`.
