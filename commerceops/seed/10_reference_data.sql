-- =====================================================================
-- CommerceOps · 10_reference_data.sql   (dataset v1)
--
-- Icerik:
--   1) Deterministic helper functions (unseeded random() KULLANILMAZ)
--   2) Reference data: category hierarchy (her iki profile'da AYNI)
--   3) co_generate(profile) — set-based fact data generator
--
-- Determinism sozlesmesi:
--   Ayni profile + ayni dataset version -> ayni business sonuclari.
--   Tum "rastgelelik" satirin kendi id'sinden turetilen bir hash'tir.
-- =====================================================================

SET search_path = commerceops, public;

-- ---------------------------------------------------------------------
-- 1) Deterministic helpers
-- ---------------------------------------------------------------------

-- Lehmer-tarzi iki turlu karistirma. Girdi ayni ise cikti her zaman ayni.
CREATE OR REPLACE FUNCTION co_hash(n bigint, salt integer)
RETURNS bigint
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$
    SELECT ((((n * 2654435761 + salt * 40503) % 2147483647) * 48271) % 2147483647);
$$;

CREATE OR REPLACE FUNCTION co_rand(n bigint, salt integer)
RETURNS double precision
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$
    SELECT co_hash(n, salt)::double precision / 2147483647.0;
$$;

-- lo..hi araliginda (dahil) deterministic tamsayi
CREATE OR REPLACE FUNCTION co_pick(n bigint, salt integer, lo integer, hi integer)
RETURNS integer
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$
    SELECT lo + (co_hash(n, salt) % (hi - lo + 1))::integer;
$$;

CREATE OR REPLACE FUNCTION co_pick_text(n bigint, salt integer, arr text[])
RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$
    SELECT arr[1 + (co_hash(n, salt) % array_length(arr, 1))::integer];
$$;

-- ---------------------------------------------------------------------
-- 2) Reference data — category hierarchy (4 seviyeye kadar)
-- ---------------------------------------------------------------------
TRUNCATE categories CASCADE;

INSERT INTO categories (id, parent_id, name, slug, is_active, created_at) VALUES
-- Level 1
(1,  NULL, 'Electronics',        'electronics',        true, '2024-01-05 09:00:00+00'),
(2,  NULL, 'Home & Living',      'home-living',        true, '2024-01-05 09:00:00+00'),
(3,  NULL, 'Fashion',            'fashion',            true, '2024-01-05 09:00:00+00'),
(4,  NULL, 'Sports & Outdoor',   'sports-outdoor',     true, '2024-01-05 09:00:00+00'),
(5,  NULL, 'Books & Media',      'books-media',        true, '2024-01-05 09:00:00+00'),
(6,  NULL, 'Beauty & Health',    'beauty-health',      true, '2024-01-05 09:00:00+00'),
-- Level 2
(10, 1, 'Computers',             'computers',          true, '2024-01-06 09:00:00+00'),
(11, 1, 'Mobile Devices',        'mobile-devices',     true, '2024-01-06 09:00:00+00'),
(12, 1, 'Audio',                 'audio',              true, '2024-01-06 09:00:00+00'),
(13, 1, 'Photography',           'photography',        true, '2024-01-06 09:00:00+00'),
(14, 2, 'Kitchen',               'kitchen',            true, '2024-01-06 09:00:00+00'),
(15, 2, 'Furniture',             'furniture',          true, '2024-01-06 09:00:00+00'),
(16, 2, 'Home Decor',            'home-decor',         true, '2024-01-06 09:00:00+00'),
(17, 3, 'Menswear',              'menswear',           true, '2024-01-06 09:00:00+00'),
(18, 3, 'Womenswear',            'womenswear',         true, '2024-01-06 09:00:00+00'),
(19, 3, 'Footwear',              'footwear',           true, '2024-01-06 09:00:00+00'),
(20, 3, 'Accessories',           'accessories',        true, '2024-01-06 09:00:00+00'),
(21, 4, 'Fitness',               'fitness',            true, '2024-01-06 09:00:00+00'),
(22, 4, 'Outdoor Gear',          'outdoor-gear',       true, '2024-01-06 09:00:00+00'),
(23, 4, 'Cycling',               'cycling',            true, '2024-01-06 09:00:00+00'),
(24, 5, 'Books',                 'books',              true, '2024-01-06 09:00:00+00'),
(25, 5, 'Music',                 'music',              true, '2024-01-06 09:00:00+00'),
(26, 5, 'Games',                 'games',              true, '2024-01-06 09:00:00+00'),
(27, 6, 'Skincare',              'skincare',           true, '2024-01-06 09:00:00+00'),
(28, 6, 'Personal Care',         'personal-care',      true, '2024-01-06 09:00:00+00'),
(29, 6, 'Supplements',           'supplements',        true, '2024-01-06 09:00:00+00'),
-- Level 3
(40, 10, 'Laptops',              'laptops',            true, '2024-01-07 09:00:00+00'),
(41, 10, 'Desktops',             'desktops',           true, '2024-01-07 09:00:00+00'),
(42, 10, 'Components',           'components',         true, '2024-01-07 09:00:00+00'),
(43, 10, 'Peripherals',          'peripherals',        true, '2024-01-07 09:00:00+00'),
(44, 11, 'Smartphones',          'smartphones',        true, '2024-01-07 09:00:00+00'),
(45, 11, 'Tablets',              'tablets',            true, '2024-01-07 09:00:00+00'),
(46, 11, 'Wearables',            'wearables',          true, '2024-01-07 09:00:00+00'),
(47, 12, 'Headphones',           'headphones',         true, '2024-01-07 09:00:00+00'),
(48, 12, 'Speakers',             'speakers',           true, '2024-01-07 09:00:00+00'),
(49, 12, 'Home Audio',           'home-audio',         true, '2024-01-07 09:00:00+00'),
(50, 13, 'Cameras',              'cameras',            true, '2024-01-07 09:00:00+00'),
(51, 13, 'Lenses',               'lenses',             true, '2024-01-07 09:00:00+00'),
(52, 14, 'Cookware',             'cookware',           true, '2024-01-07 09:00:00+00'),
(53, 14, 'Small Appliances',     'small-appliances',   true, '2024-01-07 09:00:00+00'),
(54, 14, 'Tableware',            'tableware',          true, '2024-01-07 09:00:00+00'),
(55, 15, 'Living Room',          'living-room',        true, '2024-01-07 09:00:00+00'),
(56, 15, 'Bedroom',              'bedroom',            true, '2024-01-07 09:00:00+00'),
(57, 15, 'Office Furniture',     'office-furniture',   true, '2024-01-07 09:00:00+00'),
(58, 16, 'Lighting',             'lighting',           true, '2024-01-07 09:00:00+00'),
(59, 16, 'Textiles',             'textiles',           true, '2024-01-07 09:00:00+00'),
(60, 17, 'Men Tops',             'men-tops',           true, '2024-01-07 09:00:00+00'),
(61, 17, 'Men Bottoms',          'men-bottoms',        true, '2024-01-07 09:00:00+00'),
(62, 18, 'Women Tops',           'women-tops',         true, '2024-01-07 09:00:00+00'),
(63, 18, 'Women Dresses',        'women-dresses',      true, '2024-01-07 09:00:00+00'),
(64, 19, 'Sneakers',             'sneakers',           true, '2024-01-07 09:00:00+00'),
(65, 19, 'Boots',                'boots',              true, '2024-01-07 09:00:00+00'),
(66, 20, 'Bags',                 'bags',               true, '2024-01-07 09:00:00+00'),
(67, 20, 'Watches',              'watches',            true, '2024-01-07 09:00:00+00'),
(68, 21, 'Strength Training',    'strength-training',  true, '2024-01-07 09:00:00+00'),
(69, 21, 'Yoga',                 'yoga',               true, '2024-01-07 09:00:00+00'),
(70, 22, 'Camping',              'camping',            true, '2024-01-07 09:00:00+00'),
(71, 22, 'Hiking',               'hiking',             true, '2024-01-07 09:00:00+00'),
(72, 23, 'Bikes',                'bikes',              true, '2024-01-07 09:00:00+00'),
(73, 23, 'Bike Parts',           'bike-parts',         true, '2024-01-07 09:00:00+00'),
(74, 24, 'Fiction',              'fiction',            true, '2024-01-07 09:00:00+00'),
(75, 24, 'Non-Fiction',          'non-fiction',        true, '2024-01-07 09:00:00+00'),
(76, 24, 'Technical Books',      'technical-books',    true, '2024-01-07 09:00:00+00'),
(77, 25, 'Vinyl',                'vinyl',              true, '2024-01-07 09:00:00+00'),
(78, 25, 'CDs',                  'cds',                false,'2024-01-07 09:00:00+00'),
(79, 26, 'Board Games',          'board-games',        true, '2024-01-07 09:00:00+00'),
(80, 26, 'Video Games',          'video-games',        true, '2024-01-07 09:00:00+00'),
(81, 27, 'Face Care',            'face-care',          true, '2024-01-07 09:00:00+00'),
(82, 27, 'Body Care',            'body-care',          true, '2024-01-07 09:00:00+00'),
(83, 28, 'Hair Care',            'hair-care',          true, '2024-01-07 09:00:00+00'),
(84, 28, 'Oral Care',            'oral-care',          true, '2024-01-07 09:00:00+00'),
(85, 29, 'Vitamins',             'vitamins',           true, '2024-01-07 09:00:00+00'),
(86, 29, 'Sports Nutrition',     'sports-nutrition',   true, '2024-01-07 09:00:00+00'),
-- Level 4 (recursive CTE'nin gercekten derinlesmesi icin)
(90, 40, 'Gaming Laptops',       'gaming-laptops',     true, '2024-01-08 09:00:00+00'),
(91, 40, 'Ultrabooks',           'ultrabooks',         true, '2024-01-08 09:00:00+00'),
(92, 42, 'Graphics Cards',       'graphics-cards',     true, '2024-01-08 09:00:00+00'),
(93, 42, 'Processors',           'processors',         true, '2024-01-08 09:00:00+00'),
(94, 44, 'Android Phones',       'android-phones',     true, '2024-01-08 09:00:00+00'),
(95, 44, 'iOS Phones',           'ios-phones',         true, '2024-01-08 09:00:00+00');

SELECT setval(pg_get_serial_sequence('commerceops.categories','id'),
              (SELECT max(id) FROM categories));

-- ---------------------------------------------------------------------
-- 3) Generator
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION co_generate(p_profile text)
RETURNS text
LANGUAGE plpgsql
SET search_path = commerceops, public
AS $fn$
DECLARE
    n_users     integer;
    n_merchants integer;
    n_products  integer;
    n_orders    integer;
    n_active_products integer;   -- ACTIVE status'lu urun sayisi
    n_sellable        integer;   -- fiilen satilabilen urun havuzu (kalanlar hic satilmaz)
    n_customer_pool   integer;   -- hic siparis vermeyen user'lar kalsin diye daraltilmis havuz
    n_seller_pool     integer;   -- hic urunu olmayan merchant'lar kalsin diye daraltilmis havuz

    d_start   timestamptz := '2025-01-01 00:00:00+00';
    d_span    integer     := 592;          -- gun; 2025-01-01 .. 2026-08-15
    d_ref     timestamptz := '2026-08-20 00:00:00+00';  -- sabit referans "bugun"
                                                        -- (now() KULLANILMAZ: reproducibility)
    u_start   timestamptz := '2024-06-01 00:00:00+00';
    u_span    integer     := 780;

    leaf_ids  bigint[];
    t0        timestamptz := clock_timestamp();

    first_names text[] := ARRAY['Ada','Kerem','Selin','Mert','Deniz','Elif','Baris','Zeynep','Emre','Ayse',
                                'Can','Merve','Ozan','Ipek','Tolga','Nil','Burak','Ece','Kaan','Sena',
                                'Onur','Gizem','Serkan','Yasemin','Arda','Melis','Cem','Duygu','Ufuk','Pelin'];
    last_names  text[] := ARRAY['Yilmaz','Demir','Kaya','Sahin','Celik','Yildiz','Aydin','Ozturk','Arslan','Dogan',
                                'Kilic','Aslan','Cetin','Kara','Koc','Kurt','Ozdemir','Simsek','Polat','Erdogan'];
    cities      text[] := ARRAY['Istanbul','Ankara','Izmir','Bursa','Antalya','Adana','Konya','Gaziantep',
                                'Kayseri','Eskisehir','Trabzon','Samsun','Denizli','Mugla'];
    streets     text[] := ARRAY['Bagdat Cad.','Ataturk Blv.','Cumhuriyet Sok.','Istiklal Cad.','Gazi Blv.',
                                'Mimar Sinan Sok.','Fatih Cad.','Kordon Sok.','Ege Cad.','Yildiz Sok.'];
    m_prefix    text[] := ARRAY['Nova','Atlas','Vertex','Orion','Lumen','Kaya','Delta','Zenith','Aurora','Prime',
                                'Meridian','Kobalt','Solar','Titan','Vega'];
    m_suffix    text[] := ARRAY['Trading','Supplies','Retail','Commerce','Group','Store','Works','Market','Labs','Depot'];
    p_adj       text[] := ARRAY['Compact','Premium','Classic','Ultra','Eco','Pro','Lite','Urban','Nordic','Vintage',
                                'Smart','Heavy-Duty','Slim','Portable','Ergonomic'];
    p_noun      text[] := ARRAY['Laptop Stand','Wireless Mouse','Desk Lamp','Coffee Grinder','Running Shoe',
                                'Backpack','Bluetooth Speaker','Yoga Mat','Water Bottle','Office Chair',
                                'Kitchen Knife','Notebook','Phone Case','Headphone','Monitor Arm',
                                'Camera Bag','Bike Helmet','Wool Sweater','Face Serum','Board Game',
                                'Mechanical Keyboard','Cast Iron Pan','Travel Adapter','Sleeping Bag','Desk Organizer'];
    providers   text[] := ARRAY['ADYEN','STRIPE','LOCAL_BANK','WALLET'];
    fail_codes  text[] := ARRAY['INSUFFICIENT_FUNDS','DO_NOT_HONOR','EXPIRED_CARD','3DS_FAILED','NETWORK_ERROR'];
    carriers    text[] := ARRAY['ARAS','YURTICI','MNG','UPS','PTT'];
    card_brands text[] := ARRAY['visa','mastercard','amex','troy'];
    refund_reasons text[] := ARRAY['DAMAGED','WRONG_ITEM','LATE_DELIVERY','CUSTOMER_CHANGED_MIND','PARTIAL_CANCEL'];
BEGIN
    IF p_profile = 'small' THEN
        n_users := 3000;  n_merchants := 40;  n_products := 2000;  n_orders := 12000;
    ELSIF p_profile = 'full' THEN
        n_users := 120000; n_merchants := 400; n_products := 40000; n_orders := 400000;
    ELSE
        RAISE EXCEPTION 'Bilinmeyen profile: % (small | full)', p_profile;
    END IF;

    n_active_products := floor(n_products * 0.88)::integer;
    n_sellable        := floor(n_active_products * 0.85)::integer;
    n_customer_pool   := floor(n_users * 0.60)::integer;
    n_seller_pool     := floor(n_merchants * 0.85)::integer;

    RAISE NOTICE 'CommerceOps generate: profile=% users=% merchants=% products=% orders=%',
                 p_profile, n_users, n_merchants, n_products, n_orders;

    TRUNCATE reviews, shipment_items, shipments, inventory_movements, refunds, payments,
             order_status_history, order_items, orders, warehouses, product_categories,
             products, merchant_members, addresses, merchants, users
             RESTART IDENTITY CASCADE;

    -- leaf category listesi (cocugu olmayan kategoriler)
    SELECT array_agg(c.id ORDER BY c.id) INTO leaf_ids
    FROM categories c
    WHERE NOT EXISTS (SELECT 1 FROM categories ch WHERE ch.parent_id = c.id);

    -- =================================================================
    -- users
    -- =================================================================
    INSERT INTO users (id, email, full_name, phone, status, created_at, last_login_at)
    SELECT i,
           lower(co_pick_text(i,102,first_names)) || '.' ||
           lower(co_pick_text(i,103,last_names)) || i || '@' ||
           co_pick_text(i,104, ARRAY['example.com','mail.test','corp.local','inbox.test']),
           co_pick_text(i,102,first_names) || ' ' || co_pick_text(i,103,last_names),
           CASE WHEN co_hash(i,105) % 100 < 72
                THEN '+90 5' || lpad((co_hash(i,106) % 100000000)::text, 8, '0') END,
           CASE WHEN co_hash(i,107) % 1000 < 955 THEN 'ACTIVE'
                WHEN co_hash(i,107) % 1000 < 990 THEN 'SUSPENDED'
                ELSE 'DELETED' END,
           reg.ts,
           CASE WHEN co_hash(i,109) % 100 < 82
                THEN reg.ts + make_interval(days => co_pick(i,110,1,700),
                                            mins => co_pick(i,111,0,1439)) END
    FROM generate_series(1, n_users) i
    CROSS JOIN LATERAL (
        SELECT u_start + make_interval(days => (co_rand(i,101) * u_span)::integer,
                                       mins => co_pick(i,112,0,1439)) AS ts
    ) reg;

    -- =================================================================
    -- addresses  (bazi user'larin hic adresi yok)
    -- =================================================================
    INSERT INTO addresses (user_id, label, recipient_name, line1, line2, city,
                           postal_code, country_code, is_default, created_at)
    SELECT u.id,
           CASE g WHEN 1 THEN 'Home' WHEN 2 THEN 'Work' ELSE 'Other' END,
           u.full_name,
           co_pick_text(u.id * 8 + g, 201, streets) || ' No:' || co_pick(u.id*8+g,202,1,180),
           CASE WHEN co_hash(u.id*8+g,203) % 100 < 40
                THEN 'Daire ' || co_pick(u.id*8+g,204,1,30) END,
           co_pick_text(u.id*8+g,205, cities),
           lpad(co_pick(u.id*8+g,206,1000,81999)::text, 5, '0'),
           'TR',
           (g = 1),
           u.created_at + make_interval(days => co_pick(u.id*8+g,207,0,60))
    FROM users u
    CROSS JOIN LATERAL generate_series(1, (co_hash(u.id,200) % 4)::integer) g
    ORDER BY u.id, g;

    -- =================================================================
    -- merchants
    -- =================================================================
    INSERT INTO merchants (id, name, slug, status, commission_rate, country_code, created_at)
    SELECT m,
           co_pick_text(m,301,m_prefix) || ' ' || co_pick_text(m,302,m_suffix),
           lower(co_pick_text(m,301,m_prefix)) || '-' ||
           lower(co_pick_text(m,302,m_suffix)) || '-' || m,
           CASE WHEN co_hash(m,303) % 100 < 90 THEN 'ACTIVE'
                WHEN co_hash(m,303) % 100 < 97 THEN 'SUSPENDED'
                ELSE 'CLOSED' END,
           round((0.05 + co_rand(m,304) * 0.12)::numeric, 4),
           'TR',
           u_start + make_interval(days => (co_rand(m,305) * 300)::integer)
    FROM generate_series(1, n_merchants) m;

    -- =================================================================
    -- merchant_members
    --   staff havuzu: ilk (n_merchants * 6) user
    --   bazi user birden fazla merchant'in uyesi
    --   bazi uyelikler pasif (ended_at dolu)
    -- =================================================================
    INSERT INTO merchant_members (merchant_id, user_id, role, is_active, joined_at, ended_at)
    SELECT DISTINCT ON (mm.merchant_id, mm.user_id)
           mm.merchant_id, mm.user_id, mm.role, mm.is_active, mm.joined_at, mm.ended_at
    FROM (
        SELECT m.id AS merchant_id,
               1 + (co_hash(m.id * 32 + k, 401) % LEAST(n_merchants * 6, n_users))::bigint AS user_id,
               CASE WHEN k = 1 THEN 'OWNER'
                    ELSE co_pick_text(m.id*32+k, 402, ARRAY['MANAGER','ANALYST','OPERATOR','OPERATOR']) END AS role,
               (k = 1 OR co_hash(m.id*32+k,403) % 100 >= 18) AS is_active,
               m.created_at + make_interval(days => co_pick(m.id*32+k,404,0,200)) AS joined_at,
               CASE WHEN k > 1 AND co_hash(m.id*32+k,403) % 100 < 18
                    THEN m.created_at + make_interval(days => co_pick(m.id*32+k,405,220,600)) END AS ended_at,
               k
        FROM merchants m
        CROSS JOIN LATERAL generate_series(1, 2 + (co_hash(m.id,400) % 4)::integer) k
    ) mm
    ORDER BY mm.merchant_id, mm.user_id, mm.k;

    -- =================================================================
    -- products  (merchant dagilimi skewed: bazi merchant'larin hic urunu yok)
    -- =================================================================
    INSERT INTO products (id, merchant_id, sku, name, description, status, price, currency,
                          track_inventory, weight_grams, created_at, updated_at)
    SELECT p,
           1 + (power(co_rand(p,501), 1.6) * n_seller_pool)::integer % n_seller_pool,
           'SKU-' || lpad(p::text, 7, '0'),
           co_pick_text(p,502,p_adj) || ' ' || co_pick_text(p,503,p_noun) || ' ' ||
           chr(65 + (co_hash(p,504) % 26)::integer) || co_pick(p,505,100,999),
           CASE WHEN co_hash(p,506) % 100 < 85
                THEN co_pick_text(p,502,p_adj) || ' ' || co_pick_text(p,503,p_noun) ||
                     '. ' || co_pick_text(p,507, ARRAY[
                        'Gunluk kullanim icin dayanikli malzeme.',
                        'Hafif govde, uzun omurlu tasarim.',
                        'Paket iceriginde tasima cantasi bulunur.',
                        'Iki yil ureticiden garantilidir.',
                        'Cok amacli kullanim icin uygundur.']) END,
           CASE WHEN p <= n_active_products THEN 'ACTIVE'
                WHEN p <= floor(n_products * 0.94)::integer THEN 'DRAFT'
                ELSE 'ARCHIVED' END,
           round((15 + power(co_rand(p,508), 2.6) * 5200)::numeric, 2),
           'TRY',
           (co_hash(p,509) % 100 < 90),
           CASE WHEN co_hash(p,510) % 100 < 75 THEN co_pick(p,511,80,9000) END,
           u_start + make_interval(days => (co_rand(p,512) * 700)::integer),
           u_start + make_interval(days => (co_rand(p,512) * 700)::integer)
    FROM generate_series(1, n_products) p;

    -- =================================================================
    -- product_categories  (%3 urun hic kategoriye bagli degil)
    -- =================================================================
    INSERT INTO product_categories (product_id, category_id, is_primary, assigned_at)
    SELECT d.product_id,
           d.category_id,
           (row_number() OVER (PARTITION BY d.product_id ORDER BY d.g) = 1),
           d.assigned_at
    FROM (
        SELECT DISTINCT ON (p.id, leaf_ids[1 + (co_hash(p.id * 16 + g, 601) % array_length(leaf_ids,1))::integer])
               p.id AS product_id,
               leaf_ids[1 + (co_hash(p.id * 16 + g, 601) % array_length(leaf_ids,1))::integer] AS category_id,
               g,
               p.created_at AS assigned_at
        FROM products p
        CROSS JOIN LATERAL generate_series(
                 1,
                 CASE WHEN co_hash(p.id,600) % 100 < 3 THEN 0
                      ELSE 1 + (co_hash(p.id,602) % 3)::integer END) g
        ORDER BY p.id,
                 leaf_ids[1 + (co_hash(p.id * 16 + g, 601) % array_length(leaf_ids,1))::integer],
                 g
    ) d;

    -- =================================================================
    -- warehouses  (%15 merchant'in hic deposu yok)
    -- =================================================================
    INSERT INTO warehouses (merchant_id, code, name, city, country_code, is_active, created_at)
    SELECT m.id,
           'WH-' || lpad(m.id::text, 4, '0') || '-' || k,
           co_pick_text(m.id*4+k,701,cities) || ' Depo ' || k,
           co_pick_text(m.id*4+k,701,cities),
           'TR',
           (co_hash(m.id*4+k,702) % 100 < 88),
           m.created_at + make_interval(days => co_pick(m.id*4+k,703,5,120))
    FROM merchants m
    CROSS JOIN LATERAL generate_series(
             1,
             CASE WHEN co_hash(m.id,700) % 100 < 15 THEN 0
                  ELSE 1 + (co_hash(m.id,704) % 3)::integer END) k
    ORDER BY m.id, k;

    -- =================================================================
    -- orders
    --   * customer dagilimi skewed (az sayida cok siparis veren musteri)
    --   * placed_at buyume trendi + pazar gunu dusuk hacim
    --   * %8 order icin timestamp saat basina yuvarlanir -> ayni timestamp
    --   * status siparisin yasina bagli
    -- =================================================================
    INSERT INTO orders (id, order_number, customer_id, status, currency, placed_at,
                        created_at, updated_at, shipping_address_id,
                        ship_recipient_name, ship_line1, ship_city, ship_postal_code,
                        ship_country_code, customer_note)
    SELECT o.id,
           'ORD-' || to_char(o.placed_at AT TIME ZONE 'UTC', 'YYYYMM') || '-' || lpad(o.id::text, 7, '0'),
           o.customer_id,
           o.status,
           'TRY',
           o.placed_at,
           o.placed_at,
           o.placed_at + make_interval(days => co_pick(o.id,899,0,6)),
           addr.id,
           COALESCE(addr.recipient_name, u.full_name),
           COALESCE(addr.line1, co_pick_text(o.id,801,streets) || ' No:' || co_pick(o.id,802,1,180)),
           COALESCE(addr.city, co_pick_text(o.id,803,cities)),
           COALESCE(addr.postal_code, lpad(co_pick(o.id,804,1000,81999)::text, 5, '0')),
           'TR',
           CASE WHEN co_hash(o.id,805) % 100 < 12
                THEN co_pick_text(o.id,806, ARRAY['Lutfen zile basmayin.','Kapiya birakabilirsiniz.',
                                                  'Ogleden sonra teslim edin.','Hediye paketi olsun.']) END
    FROM (
        SELECT i AS id,
               1 + (power(co_rand(i,901), 2.2) * n_customer_pool)::integer % n_customer_pool AS customer_id,
               ts.placed_at,
               CASE
                 WHEN age_days < 3  THEN CASE WHEN co_hash(i,903) % 100 < 45 THEN 'PENDING'
                                              WHEN co_hash(i,903) % 100 < 80 THEN 'PAID'
                                              ELSE 'PROCESSING' END
                 WHEN age_days < 12 THEN CASE WHEN co_hash(i,903) % 100 < 12 THEN 'PAID'
                                              WHEN co_hash(i,903) % 100 < 45 THEN 'PROCESSING'
                                              WHEN co_hash(i,903) % 100 < 90 THEN 'SHIPPED'
                                              ELSE 'CANCELLED' END
                 ELSE CASE WHEN co_hash(i,903) % 1000 < 90  THEN 'CANCELLED'
                           WHEN co_hash(i,903) % 1000 < 165 THEN 'SHIPPED'
                           WHEN co_hash(i,903) % 1000 < 210 THEN 'PROCESSING'
                           WHEN co_hash(i,903) % 1000 < 240 THEN 'PAID'
                           WHEN co_hash(i,903) % 1000 < 260 THEN 'PENDING'
                           ELSE 'DELIVERED' END
               END AS status
        FROM generate_series(1, n_orders) i
        CROSS JOIN LATERAL (
            -- %9 order gunun ayni dakikasina sabitlenir: pagination tie-breaker
            -- calismasi icin ayni placed_at degerine sahip order'lar olusur.
            SELECT CASE WHEN co_hash(i,904) % 100 < 9
                        THEN date_trunc('day', raw_ts) + interval '12 hours'
                        ELSE raw_ts END AS placed_at
            FROM (SELECT d_start
                         + make_interval(days => day_off
                                                 + CASE WHEN extract(dow FROM d_start + make_interval(days => day_off)) = 0
                                                             AND co_hash(i,906) % 100 < 45
                                                        THEN 1 ELSE 0 END,
                                         hours => co_pick(i,907,7,22),
                                         mins  => co_pick(i,908,0,59),
                                         secs  => co_pick(i,909,0,59)) AS raw_ts
                  FROM (SELECT (power(co_rand(i,902), 0.8) * d_span)::integer AS day_off) x
            ) y
        ) ts
        CROSS JOIN LATERAL (
            SELECT GREATEST(0, (EXTRACT(EPOCH FROM (d_ref - ts.placed_at)) / 86400)::integer) AS age_days
        ) a
    ) o
    JOIN users u ON u.id = o.customer_id
    LEFT JOIN LATERAL (
        SELECT a.id, a.recipient_name, a.line1, a.city, a.postal_code
        FROM addresses a
        WHERE a.user_id = o.customer_id
        ORDER BY a.is_default DESC, a.id
        LIMIT 1
    ) addr ON true;

    -- =================================================================
    -- order_items  (1-4 satir; ayni order icinde farkli merchant mumkun)
    -- =================================================================
    INSERT INTO order_items (order_id, product_id, merchant_id, quantity, unit_price, discount_amount, created_at)
    SELECT d.order_id, d.product_id, d.merchant_id, d.quantity, d.unit_price,
           CASE WHEN co_hash(d.order_id * 64 + d.product_id, 1010) % 100 < 18
                THEN round(d.unit_price * d.quantity * 0.10, 2) ELSE 0 END,
           d.created_at
    FROM (
        SELECT DISTINCT ON (o.id, pr.id)
               o.id AS order_id,
               pr.id AS product_id,
               pr.merchant_id,
               CASE WHEN co_hash(o.id*64+g, 1002) % 100 < 62 THEN 1
                    WHEN co_hash(o.id*64+g, 1002) % 100 < 86 THEN 2
                    WHEN co_hash(o.id*64+g, 1002) % 100 < 96 THEN 3
                    ELSE 4 END AS quantity,
               -- siparis anindaki fiyat: guncel fiyattan bilincli olarak farkli
               round(pr.price * (0.82 + co_rand(o.id*64+g, 1003) * 0.30)::numeric, 2) AS unit_price,
               o.created_at
        FROM orders o
        CROSS JOIN LATERAL generate_series(
                 1,
                 CASE WHEN co_hash(o.id,1000) % 100 < 52 THEN 1
                      WHEN co_hash(o.id,1000) % 100 < 82 THEN 2
                      WHEN co_hash(o.id,1000) % 100 < 95 THEN 3
                      ELSE 4 END) g
        JOIN products pr
          ON pr.id = 1 + (power(co_rand(o.id * 64 + g, 1001), 2.9) * n_sellable)::integer % n_sellable
        ORDER BY o.id, pr.id, g
    ) d;

    -- =================================================================
    -- order_status_history  (mevcut status'a giden yol)
    -- =================================================================
    INSERT INTO order_status_history (order_id, from_status, to_status, changed_at, changed_by_user_id, note)
    SELECT o.id,
           CASE WHEN s.ord > 1 THEN path.arr[s.ord - 1] END,
           s.st,
           o.placed_at + make_interval(hours => ((s.ord - 1) * 18 + co_pick((o.id*8+s.ord)::bigint, 1101, 0, 14))::integer),
           CASE WHEN co_hash((o.id*8+s.ord)::bigint,1102) % 100 < 22 THEN o.customer_id END,
           CASE WHEN s.st = 'CANCELLED'
                THEN co_pick_text(o.id,1103, ARRAY['Musteri iptali','Stok yetersiz','Odeme dogrulanamadi']) END
    FROM orders o
    CROSS JOIN LATERAL (
        SELECT CASE o.status
                 WHEN 'PENDING'    THEN ARRAY['PENDING']
                 WHEN 'PAID'       THEN ARRAY['PENDING','PAID']
                 WHEN 'PROCESSING' THEN ARRAY['PENDING','PAID','PROCESSING']
                 WHEN 'SHIPPED'    THEN ARRAY['PENDING','PAID','PROCESSING','SHIPPED']
                 WHEN 'DELIVERED'  THEN ARRAY['PENDING','PAID','PROCESSING','SHIPPED','DELIVERED']
                 ELSE CASE WHEN co_hash(o.id,1100) % 100 < 55
                           THEN ARRAY['PENDING','CANCELLED']
                           ELSE ARRAY['PENDING','PAID','CANCELLED'] END
               END AS arr
    ) path
    CROSS JOIN LATERAL unnest(path.arr) WITH ORDINALITY AS s(st, ord)
    ORDER BY o.id, s.ord;

    -- =================================================================
    -- payments
    --   PENDING order  -> %60 tek PENDING attempt, %40 hic attempt yok
    --   CANCELLED      -> %50 FAILED, %30 SUCCEEDED (sonra full refund), %20 yok
    --   digerleri      -> son attempt SUCCEEDED, oncekiler FAILED
    -- =================================================================
    CREATE TEMP TABLE tmp_order_totals ON COMMIT DROP AS
    SELECT oi.order_id,
           round(sum(oi.quantity * oi.unit_price - oi.discount_amount), 2) AS total
    FROM order_items oi
    GROUP BY oi.order_id;
    CREATE UNIQUE INDEX ON tmp_order_totals(order_id);

    INSERT INTO payments (order_id, provider, attempt_no, status, amount, currency,
                          created_at, settled_at, failure_code, provider_response)
    SELECT o.id,
           co_pick_text(o.id, 1201, providers),
           k,
           CASE WHEN k < plan.attempts THEN 'FAILED' ELSE plan.final_status END,
           t.total,
           'TRY',
           o.placed_at + make_interval(mins => (k - 1) * 25 + co_pick(o.id*8+k,1202,1,20)),
           CASE WHEN k = plan.attempts AND plan.final_status = 'SUCCEEDED'
                THEN o.placed_at + make_interval(mins => (k - 1) * 25 + co_pick(o.id*8+k,1202,1,20) + 3) END,
           CASE WHEN k < plan.attempts OR plan.final_status = 'FAILED'
                THEN co_pick_text(o.id*8+k, 1203, fail_codes) END,
           CASE WHEN co_hash(o.id*8+k,1204) % 100 < 90 THEN
                jsonb_build_object(
                  'provider_ref', 'PR-' || co_hash(o.id*8+k,1205),
                  'risk_score', (co_hash(o.id*8+k,1206) % 100),
                  'card', jsonb_build_object(
                             'brand', co_pick_text(o.id,1207,card_brands),
                             'last4', lpad((co_hash(o.id,1208) % 10000)::text, 4, '0')),
                  'three_ds', (co_hash(o.id*8+k,1209) % 100 < 60),
                  'flags', CASE WHEN co_hash(o.id*8+k,1210) % 100 < 25
                                THEN jsonb_build_array('manual_review','high_risk')
                                ELSE jsonb_build_array() END)
           END
    FROM orders o
    JOIN tmp_order_totals t ON t.order_id = o.id
    CROSS JOIN LATERAL (
        SELECT CASE
                 WHEN o.status = 'PENDING' THEN
                      CASE WHEN co_hash(o.id,1200) % 100 < 60 THEN 1 ELSE 0 END
                 WHEN o.status = 'CANCELLED' THEN
                      CASE WHEN co_hash(o.id,1200) % 100 < 80 THEN 1 ELSE 0 END
                 ELSE CASE WHEN co_hash(o.id,1200) % 100 < 75 THEN 1
                           WHEN co_hash(o.id,1200) % 100 < 95 THEN 2
                           ELSE 3 END
               END AS attempts,
               CASE
                 WHEN o.status = 'PENDING' THEN 'PENDING'
                 WHEN o.status = 'CANCELLED' THEN
                      CASE WHEN co_hash(o.id,1200) % 100 < 50 THEN 'FAILED' ELSE 'SUCCEEDED' END
                 ELSE 'SUCCEEDED'
               END AS final_status
    ) plan
    CROSS JOIN LATERAL generate_series(1, plan.attempts) k
    ORDER BY o.id, k;

    -- =================================================================
    -- refunds
    --   CANCELLED + SUCCEEDED payment -> full refund
    --   diger SUCCEEDED payment'larin ~%7'si -> partial refund
    -- =================================================================
    INSERT INTO refunds (payment_id, order_item_id, amount, reason, status, created_at, processed_at)
    SELECT p.id,
           CASE WHEN co_hash(p.id*4+k,1301) % 100 < 70 THEN item.id END,
           CASE WHEN o.status = 'CANCELLED' THEN p.amount
                -- birden fazla partial refund toplami payment tutarini asamaz
                ELSE GREATEST(0.01,
                       LEAST(trunc(p.amount / rc.refund_count, 2),
                             round(COALESCE(item.line_total, p.amount)
                                   * (0.25 + co_rand(p.id*4+k,1302) * 0.55)::numeric, 2))) END,
           CASE WHEN co_hash(p.id*4+k,1303) % 100 < 85
                THEN co_pick_text(p.id*4+k,1304, refund_reasons) END,
           st.status,
           r_ts.created_at,
           CASE WHEN st.status = 'COMPLETED' THEN r_ts.created_at + interval '6 hours'
                WHEN st.status = 'REJECTED'  THEN r_ts.created_at + interval '2 days'
                ELSE NULL END                      -- PENDING refund: processed_at NULL
    FROM payments p
    JOIN orders o ON o.id = p.order_id
    CROSS JOIN LATERAL (
        SELECT CASE
                 WHEN p.status <> 'SUCCEEDED' THEN 0
                 WHEN o.status = 'CANCELLED'  THEN 1
                 WHEN co_hash(p.id,1300) % 100 < 6 THEN 1
                 WHEN co_hash(p.id,1300) % 100 < 7 THEN 2
                 ELSE 0
               END AS refund_count
    ) rc
    CROSS JOIN LATERAL generate_series(1, rc.refund_count) k
    CROSS JOIN LATERAL (
        SELECT CASE WHEN co_hash(p.id*4+k,1305) % 100 < 92 THEN 'COMPLETED'
                    WHEN co_hash(p.id*4+k,1305) % 100 < 97 THEN 'PENDING'
                    ELSE 'REJECTED' END AS status
    ) st
    CROSS JOIN LATERAL (
        SELECT p.settled_at + make_interval(days => co_pick(p.id*4+k,1306,1,40)) AS created_at
    ) r_ts
    LEFT JOIN LATERAL (
        SELECT oi.id, round(oi.quantity * oi.unit_price - oi.discount_amount, 2) AS line_total
        FROM order_items oi
        WHERE oi.order_id = p.order_id
        ORDER BY (co_hash(oi.id + k, 1307)), oi.id
        LIMIT 1
    ) item ON true
    ORDER BY p.id, k;

    -- =================================================================
    -- shipments  (PROCESSING'in bir kismi + SHIPPED + DELIVERED)
    -- =================================================================
    INSERT INTO shipments (order_id, warehouse_id, carrier, tracking_code, status,
                           shipped_at, delivered_at, created_at)
    SELECT o.id,
           wh.id,
           co_pick_text(o.id*4+k, 1401, carriers),
           CASE WHEN sp.st <> 'PENDING'
                THEN 'TRK' || lpad((co_hash(o.id*4+k,1402) % 1000000000)::text, 10, '0') END,
           sp.st,
           CASE WHEN sp.st IN ('DISPATCHED','IN_TRANSIT','DELIVERED','RETURNED')
                THEN o.placed_at + make_interval(days => co_pick(o.id*4+k,1403,1,5),
                                                 hours => co_pick(o.id*4+k,1404,0,23)) END,
           CASE WHEN sp.st IN ('DELIVERED','RETURNED')
                THEN o.placed_at + make_interval(days => co_pick(o.id*4+k,1403,1,5)
                                                          + co_pick(o.id*4+k,1405,1,6),
                                                 hours => co_pick(o.id*4+k,1406,0,23)) END,
           o.placed_at + make_interval(days => co_pick(o.id*4+k,1407,0,2))
    FROM orders o
    CROSS JOIN LATERAL (
        SELECT CASE
                 WHEN o.status IN ('SHIPPED','DELIVERED') THEN
                      CASE WHEN co_hash(o.id,1400) % 100 < 78 THEN 1 ELSE 2 END
                 WHEN o.status = 'PROCESSING' AND co_hash(o.id,1400) % 100 < 40 THEN 1
                 ELSE 0
               END AS ship_count
    ) sc
    CROSS JOIN LATERAL generate_series(1, sc.ship_count) k
    CROSS JOIN LATERAL (
        SELECT CASE
                 WHEN o.status = 'PROCESSING' THEN 'PENDING'
                 WHEN o.status = 'SHIPPED' THEN
                      CASE WHEN co_hash(o.id*4+k,1408) % 100 < 45 THEN 'DISPATCHED' ELSE 'IN_TRANSIT' END
                 ELSE  -- DELIVERED order
                      CASE WHEN sc.ship_count = 2 AND k = 2 AND co_hash(o.id,1409) % 100 < 20
                           THEN 'IN_TRANSIT'
                           WHEN co_hash(o.id*4+k,1410) % 100 < 3 THEN 'RETURNED'
                           ELSE 'DELIVERED' END
               END AS st
    ) sp
    LEFT JOIN LATERAL (
        SELECT w.id
        FROM order_items oi
        JOIN warehouses w ON w.merchant_id = oi.merchant_id
        WHERE oi.order_id = o.id
        ORDER BY (co_hash(w.id + k, 1411)), w.id
        LIMIT 1
    ) wh ON true
    ORDER BY o.id, k;

    -- =================================================================
    -- shipment_items
    --   %5 item hic gonderilmemis, %8 eksik quantity, %12 iki shipment'a bolunmus
    -- =================================================================
    INSERT INTO shipment_items (shipment_id, order_item_id, quantity)
    SELECT s.id, oi.id, q.qty
    FROM order_items oi
    JOIN LATERAL (
        SELECT sh.id, row_number() OVER (ORDER BY sh.id) AS idx,
               count(*) OVER () AS ship_count
        FROM shipments sh
        WHERE sh.order_id = oi.order_id
    ) s ON true
    CROSS JOIN LATERAL (
        SELECT CASE
                 -- hic gonderilmemis item
                 WHEN co_hash(oi.id,1500) % 100 < 5 THEN 0
                 -- tek shipment
                 WHEN s.ship_count = 1 THEN
                      CASE WHEN co_hash(oi.id,1501) % 100 < 8 AND oi.quantity > 1
                           THEN oi.quantity - 1 ELSE oi.quantity END
                 -- iki shipment: split
                 WHEN co_hash(oi.id,1502) % 100 < 12 AND oi.quantity >= 2 THEN
                      CASE WHEN s.idx = 1 THEN ceil(oi.quantity / 2.0)::integer
                           ELSE oi.quantity - ceil(oi.quantity / 2.0)::integer END
                 -- iki shipment: tamami birine
                 WHEN s.idx = 1 + (co_hash(oi.id,1503) % 2)::integer THEN
                      CASE WHEN co_hash(oi.id,1501) % 100 < 8 AND oi.quantity > 1
                           THEN oi.quantity - 1 ELSE oi.quantity END
                 ELSE 0
               END AS qty
    ) q
    WHERE q.qty > 0
    ORDER BY s.id, oi.id;

    -- =================================================================
    -- inventory_movements
    -- =================================================================
    -- (a) INBOUND: stok girisleri
    INSERT INTO inventory_movements (warehouse_id, product_id, movement_type, quantity,
                                     occurred_at, reference_type, reference_id, metadata, created_at)
    SELECT wsel.id, p.id, 'INBOUND',
           co_pick(p.id*8+k, 1601, 25, 400),
           p.created_at + make_interval(days => co_pick(p.id*8+k,1602,1,120)),
           'MANUAL', NULL,
           CASE WHEN co_hash(p.id*8+k,1603) % 100 < 30
                THEN jsonb_build_object('source','PURCHASE_ORDER',
                                        'po_number','PO-' || co_pick(p.id*8+k,1604,10000,99999)) END,
           p.created_at + make_interval(days => co_pick(p.id*8+k,1602,1,120))
    FROM products p
    JOIN LATERAL (
        SELECT w.id
        FROM warehouses w
        WHERE w.merchant_id = p.merchant_id
        ORDER BY (co_hash(w.id + p.id, 1605)), w.id
        LIMIT 1
    ) wsel ON true
    CROSS JOIN LATERAL generate_series(1, 1 + (co_hash(p.id,1600) % 3)::integer) k
    WHERE p.track_inventory
    ORDER BY p.id, k;

    -- (b) OUTBOUND: gonderilen her shipment item
    INSERT INTO inventory_movements (warehouse_id, product_id, movement_type, quantity,
                                     occurred_at, reference_type, reference_id, metadata, created_at)
    SELECT COALESCE(sh.warehouse_id, w2.id), oi.product_id, 'OUTBOUND',
           -si.quantity,
           COALESCE(sh.shipped_at, sh.created_at),
           'SHIPMENT_ITEM', si.id, NULL,
           COALESCE(sh.shipped_at, sh.created_at)
    FROM shipment_items si
    JOIN shipments sh ON sh.id = si.shipment_id
    JOIN order_items oi ON oi.id = si.order_item_id
    JOIN products p ON p.id = oi.product_id AND p.track_inventory
    LEFT JOIN LATERAL (
        SELECT w.id FROM warehouses w WHERE w.merchant_id = oi.merchant_id ORDER BY w.id LIMIT 1
    ) w2 ON true
    WHERE COALESCE(sh.warehouse_id, w2.id) IS NOT NULL
    ORDER BY si.id;

    -- (c) RETURN: tamamlanmis item-level refund'lar
    INSERT INTO inventory_movements (warehouse_id, product_id, movement_type, quantity,
                                     occurred_at, reference_type, reference_id, metadata, created_at)
    SELECT wsel.id, oi.product_id, 'RETURN', oi.quantity,
           r.processed_at, 'REFUND', r.id,
           jsonb_build_object('reason', COALESCE(r.reason,'UNSPECIFIED')),
           r.processed_at
    FROM refunds r
    JOIN order_items oi ON oi.id = r.order_item_id
    JOIN products p ON p.id = oi.product_id AND p.track_inventory
    JOIN LATERAL (
        SELECT w.id FROM warehouses w WHERE w.merchant_id = oi.merchant_id ORDER BY w.id LIMIT 1
    ) wsel ON true
    WHERE r.status = 'COMPLETED' AND r.processed_at IS NOT NULL
    ORDER BY r.id;

    -- (d) ADJUSTMENT: sayim duzeltmeleri (metadata JSONB calismasi icin)
    INSERT INTO inventory_movements (warehouse_id, product_id, movement_type, quantity,
                                     occurred_at, reference_type, reference_id, metadata, created_at)
    SELECT wsel.id, p.id, 'ADJUSTMENT',
           CASE WHEN co_hash(p.id,1701) % 2 = 0 THEN co_pick(p.id,1702,1,12)
                ELSE -co_pick(p.id,1702,1,12) END,
           p.created_at + make_interval(days => co_pick(p.id,1703,150,500)),
           'MANUAL', NULL,
           jsonb_build_object('reason', co_pick_text(p.id,1704, ARRAY['CYCLE_COUNT','DAMAGE','LOST','FOUND']),
                              'counted_by', 'ops-' || co_pick(p.id,1705,1,12),
                              'approved', (co_hash(p.id,1706) % 100 < 70)),
           p.created_at + make_interval(days => co_pick(p.id,1703,150,500))
    FROM products p
    JOIN LATERAL (
        SELECT w.id FROM warehouses w WHERE w.merchant_id = p.merchant_id ORDER BY w.id LIMIT 1
    ) wsel ON true
    WHERE p.track_inventory AND co_hash(p.id,1700) % 100 < 4
    ORDER BY p.id;

    -- =================================================================
    -- reviews  (teslim edilmis item'larin bir kismi; product+user unique)
    -- =================================================================
    INSERT INTO reviews (product_id, user_id, order_item_id, rating, title, body,
                         is_verified, submitted_at, created_at)
    SELECT d.product_id, d.user_id, d.order_item_id, d.rating, d.title, d.body,
           true, d.ts AT TIME ZONE 'UTC', d.ts
    FROM (
        SELECT DISTINCT ON (oi.product_id, o.customer_id)
               oi.product_id,
               o.customer_id AS user_id,
               oi.id AS order_item_id,
               CASE WHEN co_hash(oi.id,1801) % 100 < 46 THEN 5
                    WHEN co_hash(oi.id,1801) % 100 < 74 THEN 4
                    WHEN co_hash(oi.id,1801) % 100 < 88 THEN 3
                    WHEN co_hash(oi.id,1801) % 100 < 96 THEN 2
                    ELSE 1 END AS rating,
               CASE WHEN co_hash(oi.id,1802) % 100 < 70
                    THEN co_pick_text(oi.id,1803, ARRAY['Beklentimi karsiladi','Fiyatina gore iyi',
                                                        'Kargo hizliydi','Ortalama bir urun','Tekrar alirim']) END AS title,
               CASE WHEN co_hash(oi.id,1804) % 100 < 55
                    THEN co_pick_text(oi.id,1805, ARRAY[
                           'Urunu iki haftadir kullaniyorum, sorun yasamadim.',
                           'Paketleme ozenliydi, urun aciklamayla uyumlu.',
                           'Kalitesi fiyatina gore makul ama daha iyisi olabilirdi.',
                           'Kurulumu kolay oldu, tavsiye ederim.']) END AS body,
               o.placed_at + make_interval(days => co_pick(oi.id,1806,6,45)) AS ts
        FROM order_items oi
        JOIN orders o ON o.id = oi.order_id
        WHERE o.status = 'DELIVERED'
          AND co_hash(oi.id, 1800) % 100 < 26
        ORDER BY oi.product_id, o.customer_id, oi.id
    ) d;

    -- =================================================================
    -- Fiyat kaymasi: urunlerin ~%40'inin guncel fiyati degistirilir.
    -- Amac: order_items.unit_price (snapshot) ile products.price (guncel)
    --       arasindaki farkin gorunur olmasi.
    -- =================================================================
    UPDATE products
    SET price = round(price * (1 + (co_rand(id, 1900) * 0.35 - 0.10))::numeric, 2),
        updated_at = '2026-07-01 10:00:00+00'
    WHERE co_hash(id, 1901) % 100 < 40;

    -- =================================================================
    -- Sequence'leri duzelt (explicit id kullanilan tablolar)
    -- =================================================================
    PERFORM setval(pg_get_serial_sequence('commerceops.users','id'),     (SELECT max(id) FROM users));
    PERFORM setval(pg_get_serial_sequence('commerceops.merchants','id'), (SELECT max(id) FROM merchants));
    PERFORM setval(pg_get_serial_sequence('commerceops.products','id'),  (SELECT max(id) FROM products));
    PERFORM setval(pg_get_serial_sequence('commerceops.orders','id'),    (SELECT max(id) FROM orders));

    RETURN format('profile=%s tamamlandi, sure=%s',
                  p_profile, (clock_timestamp() - t0)::interval(0));
END;
$fn$;
