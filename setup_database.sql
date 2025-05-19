-- Create and use the database
--CREATE DATABASE IF NOT EXISTS Inventory_Management;

--USE Inventory_Management;
USE railway;
-- User Table
CREATE TABLE IF NOT EXISTS User (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    company_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Supplier Table
CREATE TABLE IF NOT EXISTS Supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    contact_person VARCHAR(255),
    phone_number VARCHAR(20),
    email VARCHAR(255),
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- Product Table
CREATE TABLE IF NOT EXISTS Product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    unit_price DECIMAL(10,2) NOT NULL,
    quantity_available INT NOT NULL,
    minimum_quantity INT NOT NULL,
    supplier_id INT NOT NULL,
    user_id INT NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id),
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- Order Table (One order per supplier per date)
CREATE TABLE IF NOT EXISTS `Order` (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    order_date DATE NOT NULL,
    user_id INT NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id),
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- OrderItem Table (to handle multiple products per order)
CREATE TABLE IF NOT EXISTS OrderItem (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_quantity INT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES `Order`(order_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id)
);

-- Shipment Table (groups multiple orders made on the same date)
CREATE TABLE IF NOT EXISTS Shipment (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    shipment_date DATE NOT NULL,
    estimated_arrival_date DATE NOT NULL,
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE
);

-- ShipmentOrder Linking Table
CREATE TABLE IF NOT EXISTS ShipmentOrder (
    shipment_id INT,
    order_id INT,
    PRIMARY KEY (shipment_id, order_id),
    FOREIGN KEY (shipment_id) REFERENCES Shipment(shipment_id),
    FOREIGN KEY (order_id) REFERENCES `Order`(order_id)
);

-- Drop triggers if they exist to avoid errors
DROP TRIGGER IF EXISTS trg_create_order_after_product_update;
DROP TRIGGER IF EXISTS trg_create_shipment_after_order_insert;

-- Trigger to automatically create orders when products go below minimum quantity
DELIMITER $$

CREATE TRIGGER trg_create_order_after_product_update
AFTER UPDATE ON Product
FOR EACH ROW
BEGIN
    DECLARE existing_order_id INT DEFAULT NULL;

    -- Only create order if quantity is below minimum
    IF NEW.quantity_available < NEW.minimum_quantity THEN
        -- Try to find an existing order for today and this supplier
        SELECT o.order_id INTO existing_order_id
        FROM `Order` o
        WHERE o.supplier_id = NEW.supplier_id 
          AND o.order_date = CURDATE()
          AND o.user_id = NEW.user_id
        LIMIT 1;

        -- If no existing order, create one
        IF existing_order_id IS NULL THEN
            INSERT INTO `Order` (supplier_id, order_date, user_id)
            VALUES (NEW.supplier_id, CURDATE(), NEW.user_id);

            SET existing_order_id = LAST_INSERT_ID();
        END IF;

        -- Insert order item if not already present
        IF NOT EXISTS (
            SELECT 1 FROM OrderItem 
            WHERE order_id = existing_order_id AND product_id = NEW.product_id
        ) THEN
            INSERT INTO OrderItem (order_id, product_id, product_quantity)
            VALUES (
                existing_order_id,
                NEW.product_id,
                (NEW.minimum_quantity - NEW.quantity_available)
            );
        END IF;
    END IF;
END$$

DELIMITER ;

-- Trigger to automatically create shipments when multiple orders exist on the same day
DELIMITER $$

CREATE TRIGGER trg_create_shipment_after_order_insert
AFTER INSERT ON `Order`
FOR EACH ROW
BEGIN
    DECLARE same_day_orders INT;
    DECLARE existing_shipment_id INT DEFAULT NULL;

    SELECT COUNT(*) INTO same_day_orders
    FROM `Order`
    WHERE order_date = NEW.order_date AND user_id = NEW.user_id;

    IF same_day_orders >= 2 THEN
        -- Check if shipment for this date and user already exists
        SELECT shipment_id INTO existing_shipment_id
        FROM Shipment
        WHERE shipment_date = NEW.order_date AND user_id = NEW.user_id
        LIMIT 1;
        
        -- Create shipment only if not exists
        IF existing_shipment_id IS NULL THEN
            INSERT INTO Shipment (shipment_date, estimated_arrival_date, user_id)
            VALUES (NEW.order_date, DATE_ADD(NEW.order_date, INTERVAL 5 DAY), NEW.user_id);
            
            SET existing_shipment_id = LAST_INSERT_ID();
        END IF;

        -- Link the order to shipment
        INSERT INTO ShipmentOrder (shipment_id, order_id)
        VALUES (existing_shipment_id, NEW.order_id);
    END IF;
END$$

DELIMITER ;

-- Drop procedures if they exist to avoid errors
DROP PROCEDURE IF EXISTS AddProduct;
DROP PROCEDURE IF EXISTS DeleteProduct;
DROP PROCEDURE IF EXISTS RegisterUser;

-- Procedure to add a product
DELIMITER $$

CREATE PROCEDURE AddProduct(
    IN pname VARCHAR(255),
    IN pdesc TEXT,
    IN price DECIMAL(10,2),
    IN qty INT,
    IN min_qty INT,
    IN supp_id INT,
    IN uid INT
)
BEGIN
    INSERT INTO Product (name, description, unit_price, quantity_available, minimum_quantity, supplier_id, user_id)
    VALUES (pname, pdesc, price, qty, min_qty, supp_id, uid);
END$$

DELIMITER ;

-- Procedure to delete a product
DELIMITER $$

CREATE PROCEDURE DeleteProduct(IN pid INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete product: It may be referenced in orders or shipments';
    END;
    
    START TRANSACTION;
    
    -- First delete related OrderItem records
    DELETE FROM OrderItem WHERE product_id = pid;
    
    -- Then delete the product
    DELETE FROM Product WHERE product_id = pid;
    
    COMMIT;
END$$

DELIMITER ;

-- Procedure to register a new user
DELIMITER $$

CREATE PROCEDURE RegisterUser(
    IN uname VARCHAR(50),
    IN pass_hash VARCHAR(255),
    IN email_addr VARCHAR(100),
    IN company VARCHAR(100)
)
BEGIN
    INSERT INTO User (username, password_hash, email, company_name)
    VALUES (uname, pass_hash, email_addr, company);
END$$

DELIMITER ;

-- Drop views if they exist to avoid errors
DROP VIEW IF EXISTS LowStockProducts;
DROP VIEW IF EXISTS TodayShipments;

-- View to monitor low stock products (filtered by user)
CREATE VIEW LowStockProducts AS
SELECT product_id, name, quantity_available, minimum_quantity, supplier_id, user_id
FROM Product
WHERE quantity_available < minimum_quantity;

-- View for today's shipments (filtered by user)
CREATE VIEW TodayShipments AS
SELECT s.shipment_id, s.shipment_date, o.order_id, oi.product_id, oi.product_quantity, s.user_id
FROM Shipment s
JOIN ShipmentOrder so ON s.shipment_id = so.shipment_id
JOIN `Order` o ON so.order_id = o.order_id
JOIN OrderItem oi ON o.order_id = oi.order_id
WHERE s.shipment_date = CURDATE();

-- Sample admin user (password: admin123)
INSERT INTO User (username, password_hash, email, company_name)
VALUES ('admin', '$2b$12$1tCYGe5k5QWP8OG.2xQSR.QZfBiQNB5ozNpqg/5tdiVXyfO0A1Yxm', 'admin@example.com', 'Demo Company');

-- Sample data (Optional - uncomment to use)
/*
-- Add sample suppliers
INSERT INTO Supplier (name, address, contact_person, phone_number, email)
VALUES 
('ABC Suppliers', '123 Main St, City', 'John Doe', '555-1234', 'john@abc.com'),
('XYZ Corporation', '456 Market St, Town', 'Jane Smith', '555-5678', 'jane@xyz.com'),
('Tech Parts Inc', '789 Tech Blvd, Valley', 'Mike Johnson', '555-9012', 'mike@techparts.com');

-- Add sample products
INSERT INTO Product (name, description, unit_price, quantity_available, minimum_quantity, supplier_id)
VALUES
('Laptop', 'High performance laptop', 899.99, 15, 10, 1),
('Smartphone', 'Latest model smartphone', 499.99, 25, 20, 1),
('Keyboard', 'Mechanical gaming keyboard', 79.99, 8, 15, 2),
('Mouse', 'Wireless optical mouse', 29.99, 12, 15, 2),
('Monitor', '27-inch 4K display', 299.99, 5, 10, 3);
*/ 