-- Explicit text casts keep status/reason CHECK catalog definitions stable through pg_dump/restore.
ALTER TABLE customers
    ADD CONSTRAINT customers_email_key UNIQUE (email),
    ADD CONSTRAINT customers_email_nonempty CHECK (btrim(email) <> ''),
    ADD CONSTRAINT customers_name_nonempty CHECK (btrim(name) <> '');
ALTER TABLE categories
    ADD CONSTRAINT categories_parent_fk FOREIGN KEY (parent_id) REFERENCES categories(id),
    ADD CONSTRAINT categories_not_self_parent CHECK (parent_id <> id),
    ADD CONSTRAINT categories_name_nonempty CHECK (btrim(name) <> '');
ALTER TABLE products
    ADD CONSTRAINT products_category_fk FOREIGN KEY (category_id) REFERENCES categories(id),
    ADD CONSTRAINT products_price_check CHECK (price >= 0 AND price < 'Infinity'::numeric),
    ADD CONSTRAINT products_name_nonempty CHECK (btrim(name) <> '');
ALTER TABLE orders
    ADD CONSTRAINT orders_customer_fk FOREIGN KEY (customer_id) REFERENCES customers(id),
    ADD CONSTRAINT orders_status_check CHECK (status::text IN ('PENDING','PAID','SHIPPED','COMPLETED','CANCELLED'));
ALTER TABLE order_items
    ADD CONSTRAINT order_items_order_fk FOREIGN KEY (order_id) REFERENCES orders(id),
    ADD CONSTRAINT order_items_product_fk FOREIGN KEY (product_id) REFERENCES products(id),
    ADD CONSTRAINT order_items_quantity_check CHECK (quantity > 0),
    ADD CONSTRAINT order_items_price_check CHECK (unit_price >= 0 AND unit_price < 'Infinity'::numeric);
ALTER TABLE payments
    ADD CONSTRAINT payments_order_fk FOREIGN KEY (order_id) REFERENCES orders(id),
    ADD CONSTRAINT payments_status_check CHECK (status::text IN ('PENDING','SUCCEEDED','FAILED','REFUNDED')),
    ADD CONSTRAINT payments_amount_check CHECK (amount >= 0 AND amount < 'Infinity'::numeric),
    ADD CONSTRAINT payments_provider_nonempty CHECK (btrim(provider) <> '');
ALTER TABLE shipments
    ADD CONSTRAINT shipments_order_fk FOREIGN KEY (order_id) REFERENCES orders(id),
    ADD CONSTRAINT shipments_order_key UNIQUE (order_id),
    ADD CONSTRAINT shipments_status_check CHECK (status::text IN ('PENDING','SHIPPED','DELIVERED')),
    ADD CONSTRAINT shipments_dates_check CHECK (
        (status = 'PENDING' AND shipped_at IS NULL AND delivered_at IS NULL)
        OR (status = 'SHIPPED' AND shipped_at IS NOT NULL AND delivered_at IS NULL)
        OR (status = 'DELIVERED' AND shipped_at IS NOT NULL AND delivered_at IS NOT NULL AND delivered_at >= shipped_at)
    );
ALTER TABLE order_status_history
    ADD CONSTRAINT order_status_history_order_fk FOREIGN KEY (order_id) REFERENCES orders(id),
    ADD CONSTRAINT order_status_history_status_check CHECK (status::text IN ('PENDING','PAID','SHIPPED','COMPLETED','CANCELLED'));
ALTER TABLE inventory_movements
    ADD CONSTRAINT inventory_movements_product_fk FOREIGN KEY (product_id) REFERENCES products(id),
    ADD CONSTRAINT inventory_movements_delta_check CHECK (quantity_delta <> 0),
    ADD CONSTRAINT inventory_movements_reason_check CHECK (reason::text IN ('RESTOCK','SALE','RETURN','ADJUSTMENT')),
    ADD CONSTRAINT inventory_movements_sign_check CHECK (
        reason = 'ADJUSTMENT' OR (reason::text IN ('RESTOCK','RETURN') AND quantity_delta > 0)
        OR (reason = 'SALE' AND quantity_delta < 0)
    );
