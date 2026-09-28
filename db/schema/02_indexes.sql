CREATE INDEX categories_parent_idx ON categories(parent_id);
CREATE INDEX products_category_idx ON products(category_id);
CREATE INDEX orders_customer_created_id_idx ON orders(customer_id, created_at, id);
CREATE INDEX order_items_order_idx ON order_items(order_id);
CREATE INDEX order_items_product_idx ON order_items(product_id);
CREATE INDEX payments_order_created_id_idx ON payments(order_id, created_at, id);
-- shipments.order_id is already covered by its unique constraint.
CREATE INDEX order_status_history_order_changed_id_idx ON order_status_history(order_id, changed_at, id);
CREATE INDEX inventory_movements_product_created_id_idx ON inventory_movements(product_id, created_at, id);
