# MiniCommerce PostgreSQL workspace

SQL Query Engineering kursunun yerel PostgreSQL 17 ortamı. Kaynak sözleşme:
[MINICOMMERCE_DATASET_SPEC.md](MINICOMMERCE_DATASET_SPEC.md). Uygulama/API veya ders içeriği içermez.

## Başlatma

Gereksinimler: Docker Engine/Desktop, Docker Compose v2 (`--wait` desteği), Bash ve
`shasum`. Host üzerinde PostgreSQL, Python veya başka paket kurulması gerekmez.

```bash
./db/scripts/seed.sh small
```

Bu tek shell komutu PostgreSQL'i başlatır, SQL kaynaklarından schema ile **small ve
full** dataset'lerini yeniden üretip doğrular ve seçilen dataset'i `minicommerce`
veritabanına yükler. Parametre verilmezse `small` seçilir; `./db/scripts/seed.sh full`
aynı işlemin sonunda full dataset'i yükler. Mevcut kurs verileri başlangıç
dataset'iyle değiştirilir. SSH üzerinden projeyi barındıran makineye zaten
bağlıysanız repository dizininde aynı komutu çalıştırabilirsiniz.

Dump dosyaları mevcutsa yalnız `reset-small.sh` yeterlidir. Scriptler başka bir
dizinden de çağrılabilir; repository kökünü kendileri bulur. İlk `compose up`
yalnız boş `minicommerce` veritabanını oluşturur; seed için reset/build gerekir.

Bağlantı: `localhost:5436`, database/user/password: `minicommerce`.
Bu sabit parola yalnız yerel kurs ortamı içindir; port sadece `127.0.0.1` adresine açıktır.
Port doluysa komutları `POSTGRES_PORT=55432` ortam değişkeniyle çalıştırın.

```bash
docker compose exec postgres psql -U minicommerce -d minicommerce
db/scripts/reset-full.sh
db/scripts/verify-dataset.sh full
db/scripts/reset-small.sh
docker compose stop
```

Reset, çalışma veritabanındaki kurs değişikliklerini siler ve açık bağlantılarını
kapatır. Dump önce ayrı veritabanına tek transaction ile restore edilir, `ANALYZE`
ve verification çalışır; başarılı sonuç çalışma veritabanının yerini alır.
Son iki veritabanı değiştirme komutu arasında kısa bir bağlantı kesintisi vardır.
Bu aşamada kesinti yaşanırsa doğrulanmış `minicommerce_restore_small/full` veritabanı
korunur; `postgres` veritabanından `ALTER DATABASE … RENAME TO minicommerce` ile
tamamlanabilir. Restore veya doğrulama hatası mevcut çalışma veritabanını etkilemez.

## Dataset üretimi ve kontrolü

```bash
db/scripts/build-datasets.sh small  # yalnız small arşivini yeniden üret
db/scripts/build-datasets.sh full   # yalnız full arşivini yeniden üret
db/scripts/fingerprint.sh           # her tablo için sıralı içerik özeti
db/scripts/test-verification.sh     # constraint ve bozulma yakalama kontrolleri
```

Üretim geçici `minicommerce_build_*` veritabanında çalışır; mevcut kurs veritabanını
değiştirmez. Constraint'ler seed yüklenirken aktiftir, ek index'ler sonra kurulur.
Verification başarısızsa dump üretilmez. Arşiv, aynı dizinde geçici dosyaya yazılır
ve tamamlandığında taşınır; SHA-256 yan dosyası restore öncesinde kontrol edilir.
Dump'lar şema, constraint, index, identity sequence ve veriyi birlikte içerir.
PostgreSQL 17 `pg_dump/pg_restore` doğrudan container içinde kullanılır.

`small/full.fingerprints.csv` dosyaları her satırın tüm kolonlarını ve `id` sırasını
kontrol eden, sürümlenen mantıksal içerik özetleridir. Dump başlığı üretim zamanını
içerebildiği için dump dosyalarının byte olarak eşit olması beklenmez. Veri ve
fingerprint'ler deterministiktir. Kurs sırasında veri değiştirdikten sonra pristine
dataset verification'ın başarısız olması normaldir; reset ile başlangıca dönün.

İşlemler `.local/dataset.lock` ile seri çalışır. Zorla kapatılmış bir işlemden sonra
başka build/reset/test çalışmadığını kontrol edip bu boş dizini kaldırabilirsiniz.
Başarısız işlemden kalan `minicommerce_build_*` / `minicommerce_restore_*` geçici
veritabanları sonraki aynı işlemde yeniden oluşturulur.

Büyük dump ve checksum dosyaları yerel kalır, Git'e eklenmez. SQL üreticisi,
beklenen sayılar ve içerik fingerprint'leri sürümlenir. Full çalışma sırasında
dump, staging DB ve mevcut DB için birkaç GB boş disk ayırın.

## Dosyalar

- [SCHEMA_MAP.md](docs/SCHEMA_MAP.md): ilişkiler ve index gerekçeleri.
- [DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md): tüm kolonlar ve veri anlamları.
- [DATASET_MANIFEST.md](docs/DATASET_MANIFEST.md): sürüm, exact count, UTC aralıkları ve edge-case referansları.
- `queries/01_*.sql` … `08_*.sql`: sözleşmedeki sekiz modülün boş çalışma dosyaları.

ChatGPT Project Source'a yukarıdaki üç doküman taşınabilir; dump yüklemek gerekmez.
