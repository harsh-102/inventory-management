-- Create tables
CREATE TABLE IF NOT EXISTS "User" (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    company_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Supplier" (
    supplier_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    contact_person VARCHAR(255),
    phone_number VARCHAR(20),
    email VARCHAR(255),
    user_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES "User"(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "Product" (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    unit_price DECIMAL(10,2) NOT NULL,
    quantity_available INTEGER NOT NULL,
    minimum_quantity INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES "Supplier"(supplier_id),
    FOREIGN KEY (user_id) REFERENCES "User"(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "Order" (
    order_id SERIAL PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES "Supplier"(supplier_id),
    FOREIGN KEY (user_id) REFERENCES "User"(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "OrderItem" (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    product_quantity INTEGER NOT NULL,
    FOREIGN KEY (order_id) REFERENCES "Order"(order_id),
    FOREIGN KEY (product_id) REFERENCES "Product"(product_id)
);

CREATE TABLE IF NOT EXISTS "Shipment" (
    shipment_id SERIAL PRIMARY KEY,
    shipment_date DATE NOT NULL,
    estimated_arrival_date DATE NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES "User"(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS "ShipmentOrder" (
    shipment_id INTEGER,
    order_id INTEGER,
    PRIMARY KEY (shipment_id, order_id),
    FOREIGN KEY (shipment_id) REFERENCES "Shipment"(shipment_id),
    FOREIGN KEY (order_id) REFERENCES "Order"(order_id)
);

-- Create functions and triggers
CREATE OR REPLACE FUNCTION create_order_after_product_update()
RETURNS TRIGGER AS $$
DECLARE
    existing_order_id INTEGER;
BEGIN
    -- Only create order if quantity is below minimum
    IF NEW.quantity_available < NEW.minimum_quantity THEN
        -- Try to find an existing order for today and this supplier
        SELECT o.order_id INTO existing_order_id
        FROM "Order" o
        WHERE o.supplier_id = NEW.supplier_id 
          AND o.order_date = CURRENT_DATE
          AND o.user_id = NEW.user_id
        LIMIT 1;

        -- If no existing order, create one
        IF existing_order_id IS NULL THEN
            INSERT INTO "Order" (supplier_id, order_date, user_id)
            VALUES (NEW.supplier_id, CURRENT_DATE, NEW.user_id)
            RETURNING order_id INTO existing_order_id;
        END IF;

        -- Insert order item if not already present
        IF NOT EXISTS (
            SELECT 1 FROM "OrderItem" 
            WHERE order_id = existing_order_id AND product_id = NEW.product_id
        ) THEN
            INSERT INTO "OrderItem" (order_id, product_id, product_quantity)
            VALUES (
                existing_order_id,
                NEW.product_id,
                (NEW.minimum_quantity - NEW.quantity_available)
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_shipment_after_order_insert()
RETURNS TRIGGER AS $$
DECLARE
    same_day_orders INTEGER;
    existing_shipment_id INTEGER;
BEGIN
    SELECT COUNT(*) INTO same_day_orders
    FROM "Order"
    WHERE order_date = NEW.order_date AND user_id = NEW.user_id;

    IF same_day_orders >= 2 THEN
        -- Check if shipment for this date and user already exists
        SELECT shipment_id INTO existing_shipment_id
        FROM "Shipment"
        WHERE shipment_date = NEW.order_date AND user_id = NEW.user_id
        LIMIT 1;
        
        -- Create shipment only if not exists
        IF existing_shipment_id IS NULL THEN
            INSERT INTO "Shipment" (shipment_date, estimated_arrival_date, user_id)
            VALUES (NEW.order_date, NEW.order_date + INTERVAL '5 days', NEW.user_id)
            RETURNING shipment_id INTO existing_shipment_id;
        END IF;

        -- Link the order to shipment
        INSERT INTO "ShipmentOrder" (shipment_id, order_id)
        VALUES (existing_shipment_id, NEW.order_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS trg_create_order_after_product_update ON "Product";
CREATE TRIGGER trg_create_order_after_product_update
    AFTER UPDATE ON "Product"
    FOR EACH ROW
    EXECUTE FUNCTION create_order_after_product_update();

DROP TRIGGER IF EXISTS trg_create_shipment_after_order_insert ON "Order";
CREATE TRIGGER trg_create_shipment_after_order_insert
    AFTER INSERT ON "Order"
    FOR EACH ROW
    EXECUTE FUNCTION create_shipment_after_order_insert();

-- Create views
CREATE OR REPLACE VIEW "LowStockProducts" AS
SELECT product_id, name, quantity_available, minimum_quantity, supplier_id, user_id
FROM "Product"
WHERE quantity_available < minimum_quantity;

CREATE OR REPLACE VIEW "TodayShipments" AS
SELECT s.shipment_id, s.shipment_date, o.order_id, oi.product_id, oi.product_quantity, s.user_id
FROM "Shipment" s
JOIN "ShipmentOrder" so ON s.shipment_id = so.shipment_id
JOIN "Order" o ON so.order_id = o.order_id
JOIN "OrderItem" oi ON o.order_id = oi.order_id
WHERE s.shipment_date = CURRENT_DATE;

-- Create functions for product management
CREATE OR REPLACE FUNCTION add_product(
    pname VARCHAR(255),
    pdesc TEXT,
    price DECIMAL(10,2),
    qty INTEGER,
    min_qty INTEGER,
    supp_id INTEGER,
    uid INTEGER
) RETURNS INTEGER AS $$
DECLARE
    new_product_id INTEGER;
BEGIN
    INSERT INTO "Product" (name, description, unit_price, quantity_available, minimum_quantity, supplier_id, user_id)
    VALUES (pname, pdesc, price, qty, min_qty, supp_id, uid)
    RETURNING product_id INTO new_product_id;
    RETURN new_product_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_product(pid INTEGER) RETURNS VOID AS $$
BEGIN
    -- First delete related OrderItem records
    DELETE FROM "OrderItem" WHERE product_id = pid;
    
    -- Then delete the product
    DELETE FROM "Product" WHERE product_id = pid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION register_user(
    uname VARCHAR(50),
    pass_hash VARCHAR(255),
    email_addr VARCHAR(100),
    company VARCHAR(100)
) RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    INSERT INTO "User" (username, password_hash, email, company_name)
    VALUES (uname, pass_hash, email_addr, company)
    RETURNING user_id INTO new_user_id;
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;

-- Insert default admin user (password: admin123)
INSERT INTO "User" (username, password_hash, email, company_name)
VALUES ('admin', '$2b$12$1tCYGe5k5QWP8OG.2xQSR.QZfBiQNB5ozNpqg/5tdiVXyfO0A1Yxm', 'admin@example.com', 'Demo Company')
ON CONFLICT (username) DO NOTHING; 