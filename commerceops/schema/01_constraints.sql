-- =====================================================================
-- CommerceOps · 01_constraints.sql
-- Foreign key, unique ve check constraint'ler.
-- Not: Constraint'lerin schema'dan ayri tutulmasi bilinclidir; boylece
--      relationship map'i tek dosyadan okuyabilirsin.
-- =====================================================================

SET search_path = commerceops, public;

-- ---------- unique constraints ----------
ALTER TABLE users              ADD CONSTRAINT uq_users_email             UNIQUE (email);
ALTER TABLE merchants          ADD CONSTRAINT uq_merchants_slug          UNIQUE (slug);
ALTER TABLE merchant_members   ADD CONSTRAINT uq_member_merchant_user    UNIQUE (merchant_id, user_id);
ALTER TABLE categories         ADD CONSTRAINT uq_categories_slug         UNIQUE (slug);
ALTER TABLE products           ADD CONSTRAINT uq_products_sku            UNIQUE (sku);
ALTER TABLE orders             ADD CONSTRAINT uq_orders_order_number     UNIQUE (order_number);
ALTER TABLE order_items        ADD CONSTRAINT uq_order_item_order_product UNIQUE (order_id, product_id);
ALTER TABLE payments           ADD CONSTRAINT uq_payment_order_attempt   UNIQUE (order_id, attempt_no);
ALTER TABLE warehouses         ADD CONSTRAINT uq_warehouses_code         UNIQUE (code);
ALTER TABLE shipment_items     ADD CONSTRAINT uq_shipment_item_pair      UNIQUE (shipment_id, order_item_id);
ALTER TABLE reviews            ADD CONSTRAINT uq_review_product_user     UNIQUE (product_id, user_id);

-- ---------- foreign keys ----------
ALTER TABLE addresses          ADD CONSTRAINT fk_addresses_user
    FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE merchant_members   ADD CONSTRAINT fk_member_merchant
    FOREIGN KEY (merchant_id) REFERENCES merchants(id);
ALTER TABLE merchant_members   ADD CONSTRAINT fk_member_user
    FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE categories         ADD CONSTRAINT fk_category_parent
    FOREIGN KEY (parent_id) REFERENCES categories(id);

ALTER TABLE products           ADD CONSTRAINT fk_products_merchant
    FOREIGN KEY (merchant_id) REFERENCES merchants(id);

ALTER TABLE product_categories ADD CONSTRAINT fk_pc_product
    FOREIGN KEY (product_id) REFERENCES products(id);
ALTER TABLE product_categories ADD CONSTRAINT fk_pc_category
    FOREIGN KEY (category_id) REFERENCES categories(id);

ALTER TABLE orders             ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES users(id);
ALTER TABLE orders             ADD CONSTRAINT fk_orders_address
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(id);

ALTER TABLE order_items        ADD CONSTRAINT fk_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE order_items        ADD CONSTRAINT fk_items_product
    FOREIGN KEY (product_id) REFERENCES products(id);
ALTER TABLE order_items        ADD CONSTRAINT fk_items_merchant
    FOREIGN KEY (merchant_id) REFERENCES merchants(id);

ALTER TABLE order_status_history ADD CONSTRAINT fk_history_order
    FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE order_status_history ADD CONSTRAINT fk_history_user
    FOREIGN KEY (changed_by_user_id) REFERENCES users(id);

ALTER TABLE payments           ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(id);

ALTER TABLE refunds            ADD CONSTRAINT fk_refunds_payment
    FOREIGN KEY (payment_id) REFERENCES payments(id);
ALTER TABLE refunds            ADD CONSTRAINT fk_refunds_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);

ALTER TABLE warehouses         ADD CONSTRAINT fk_warehouses_merchant
    FOREIGN KEY (merchant_id) REFERENCES merchants(id);

ALTER TABLE inventory_movements ADD CONSTRAINT fk_movements_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id);
ALTER TABLE inventory_movements ADD CONSTRAINT fk_movements_product
    FOREIGN KEY (product_id) REFERENCES products(id);

ALTER TABLE shipments          ADD CONSTRAINT fk_shipments_order
    FOREIGN KEY (order_id) REFERENCES orders(id);
ALTER TABLE shipments          ADD CONSTRAINT fk_shipments_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id);

ALTER TABLE shipment_items     ADD CONSTRAINT fk_shipitems_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipments(id);
ALTER TABLE shipment_items     ADD CONSTRAINT fk_shipitems_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);

ALTER TABLE reviews            ADD CONSTRAINT fk_reviews_product
    FOREIGN KEY (product_id) REFERENCES products(id);
ALTER TABLE reviews            ADD CONSTRAINT fk_reviews_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE reviews            ADD CONSTRAINT fk_reviews_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(id);

-- ---------- check constraints ----------
ALTER TABLE users  ADD CONSTRAINT ck_users_status
    CHECK (status IN ('ACTIVE','SUSPENDED','DELETED'));

ALTER TABLE merchants ADD CONSTRAINT ck_merchants_status
    CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'));

ALTER TABLE merchant_members ADD CONSTRAINT ck_member_role
    CHECK (role IN ('OWNER','MANAGER','ANALYST','OPERATOR'));

ALTER TABLE products ADD CONSTRAINT ck_products_status
    CHECK (status IN ('ACTIVE','DRAFT','ARCHIVED'));
ALTER TABLE products ADD CONSTRAINT ck_products_price
    CHECK (price >= 0);

ALTER TABLE orders ADD CONSTRAINT ck_orders_status
    CHECK (status IN ('PENDING','PAID','PROCESSING','SHIPPED','DELIVERED','CANCELLED'));

ALTER TABLE order_items ADD CONSTRAINT ck_items_quantity   CHECK (quantity > 0);
ALTER TABLE order_items ADD CONSTRAINT ck_items_unit_price CHECK (unit_price >= 0);
ALTER TABLE order_items ADD CONSTRAINT ck_items_discount   CHECK (discount_amount >= 0);

ALTER TABLE order_status_history ADD CONSTRAINT ck_history_status
    CHECK (to_status IN ('PENDING','PAID','PROCESSING','SHIPPED','DELIVERED','CANCELLED'));

ALTER TABLE payments ADD CONSTRAINT ck_payments_status
    CHECK (status IN ('PENDING','SUCCEEDED','FAILED','CANCELLED'));
ALTER TABLE payments ADD CONSTRAINT ck_payments_provider
    CHECK (provider IN ('ADYEN','STRIPE','LOCAL_BANK','WALLET'));
ALTER TABLE payments ADD CONSTRAINT ck_payments_attempt
    CHECK (attempt_no >= 1);
ALTER TABLE payments ADD CONSTRAINT ck_payments_settled
    CHECK ((status = 'SUCCEEDED' AND settled_at IS NOT NULL)
        OR (status <> 'SUCCEEDED' AND settled_at IS NULL));

ALTER TABLE refunds ADD CONSTRAINT ck_refunds_status
    CHECK (status IN ('PENDING','COMPLETED','REJECTED'));
ALTER TABLE refunds ADD CONSTRAINT ck_refunds_amount
    CHECK (amount > 0);

ALTER TABLE inventory_movements ADD CONSTRAINT ck_movement_type
    CHECK (movement_type IN ('INBOUND','OUTBOUND','RETURN','ADJUSTMENT'));
ALTER TABLE inventory_movements ADD CONSTRAINT ck_movement_sign
    CHECK (
        (movement_type IN ('INBOUND','RETURN') AND quantity > 0)
     OR (movement_type = 'OUTBOUND'           AND quantity < 0)
     OR (movement_type = 'ADJUSTMENT'         AND quantity <> 0)
    );

ALTER TABLE shipments ADD CONSTRAINT ck_shipments_status
    CHECK (status IN ('PENDING','DISPATCHED','IN_TRANSIT','DELIVERED','RETURNED','CANCELLED'));

ALTER TABLE shipment_items ADD CONSTRAINT ck_shipitems_quantity CHECK (quantity > 0);

ALTER TABLE reviews ADD CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5);
