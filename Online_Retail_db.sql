/* ============================================================
   ONLINE RETAIL DATABASE — Customers, Orders, Products,
   OrderItems, Payments
   Target: SQL Server (T-SQL)
   ============================================================ */

-- Drop tables if they already exist (in dependency order — 
-- children before parents, since FKs would block deletion otherwise)
IF OBJECT_ID('Payments', 'U') IS NOT NULL DROP TABLE Payments;
DROP TABLE IF EXISTS Payment; -- It is the same thing, just that new 
--versions of SQL support IF EXISTS functions and older ones used OBJECT_ID
IF OBJECT_ID('OrderItems', 'U') IS NOT NULL DROP TABLE OrderItems;
IF OBJECT_ID('Orders', 'U') IS NOT NULL DROP TABLE Orders;
IF OBJECT_ID('Products', 'U') IS NOT NULL DROP TABLE Products;
IF OBJECT_ID('Customers', 'U') IS NOT NULL DROP TABLE Customers;
GO

/* ============================================================
   1. CUSTOMERS — one row per customer
   ============================================================ */
CREATE TABLE Customers (
    customer_id     INT IDENTITY(1,1) PRIMARY KEY,   -- auto-incrementing PK
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,     -- no two customers share an email
    signup_date     DATE         NOT NULL DEFAULT GETDATE(),
    city            VARCHAR(50)  NULL
);
GO

/* ============================================================
   2. PRODUCTS — one row per sellable product
   ============================================================ */
CREATE TABLE Products (
    product_id      INT IDENTITY(1,1) PRIMARY KEY,
    product_name    VARCHAR(100) NOT NULL,
    category        VARCHAR(50)  NOT NULL,
    price           DECIMAL(10,2) NOT NULL CHECK (price > 0),   -- constraint: no free/negative products
    stock_quantity  INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0)
);
GO
\


/* ============================================================
   3. ORDERS — one row per order placed by a customer
   ============================================================ */
CREATE TABLE Orders (
    order_id        INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     INT NOT NULL,
    order_date      DATETIME NOT NULL DEFAULT GETDATE(),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','processing','delivered','cancelled')),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
);
GO

-- Index on the FK — Orders.customer_id is joined on constantly
-- (SQL Server does NOT auto-index foreign keys, unlike primary keys)
CREATE INDEX idx_orders_customer_id ON Orders(customer_id);
GO

/* ============================================================
   4. ORDERITEMS — junction table: one row per product,
      per order (many-to-many between Orders and Products)
   ============================================================ */
CREATE TABLE OrderItems (
    order_item_id   INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT NOT NULL,
    product_id      INT NOT NULL,
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),  -- price AT time of sale
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (order_id)
        REFERENCES Orders(order_id),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (product_id)
        REFERENCES Products(product_id)
);
GO

CREATE INDEX idx_orderitems_order_id ON OrderItems(order_id);
CREATE INDEX idx_orderitems_product_id ON OrderItems(product_id);
GO

/* ============================================================
   5. PAYMENTS — one row per payment made against an order
   ============================================================ */
CREATE TABLE Payments (
    payment_id      INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT NOT NULL,
    payment_date    DATETIME NOT NULL DEFAULT GETDATE(),
    amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    payment_method  VARCHAR(20) NOT NULL
                    CHECK (payment_method IN ('card','eft','cash','instant_eft')),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (order_id)
        REFERENCES Orders(order_id)
);
GO

CREATE INDEX idx_payments_order_id ON Payments(order_id);
GO

/* ============================================================
   SAMPLE DATA
   ============================================================ */
INSERT INTO Customers (first_name, last_name, email, city) VALUES
('Thabo', 'Nkosi', 'thabo.nkosi@example.com', 'Johannesburg'),
('Aisha', 'Patel', 'aisha.patel@example.com', 'Cape Town'),
('Sipho', 'Dlamini', 'sipho.dlamini@example.com', 'Durban'),
('Lerato', 'Molefe', 'lerato.molefe@example.com', 'Johannesburg'),
('Chris', 'van der Merwe', 'chris.vdm@example.com', NULL);

INSERT INTO Products (product_name, category, price, stock_quantity) VALUES
('Wireless Mouse', 'Electronics', 249.99, 150),
('Mechanical Keyboard', 'Electronics', 899.00, 80),
('Running Shoes', 'Sportswear', 1099.00, 60),
('Yoga Mat', 'Sportswear', 349.50, 120),
('Coffee Beans 1kg', 'Groceries', 189.00, 200),
('Novel: Dune', 'Books', 259.00, 45);

INSERT INTO Orders (customer_id, order_date, status) VALUES
(1, '2026-06-01', 'delivered'),
(1, '2026-07-15', 'delivered'),
(2, '2026-07-20', 'processing'),
(3, '2026-08-05', 'delivered'),
(4, '2026-08-10', 'pending'),
(5, '2026-08-20', 'cancelled');

INSERT INTO OrderItems (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 2, 249.99),
(1, 5, 1, 189.00),
(2, 2, 1, 899.00),
(3, 3, 1, 1099.00),
(3, 4, 2, 349.50),
(4, 6, 3, 259.00),
(5, 1, 1, 249.99),
(6, 2, 1, 899.00);

INSERT INTO Payments (order_id, amount, payment_method) VALUES
(1, 688.98, 'card'),
(2, 899.00, 'eft'),
(3, 1798.00, 'card'),
(4, 777.00, 'instant_eft');
-- Note: orders 5 and 6 have no payment yet (pending/cancelled) — 
-- so we can't necessarily include the payments for those orders since 
-- they haven't been bpaid as yet

GO

/* ============================================================
   VERIFICATION QUERIES — confirm the build worked
   ============================================================ */

-- Row counts per table
SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'OrderItems', COUNT(*) FROM OrderItems
UNION ALL
SELECT 'Payments', COUNT(*) FROM Payments;

-- Orders with no payment yet 
SELECT o.order_id, o.status, o.order_date
FROM Orders o
LEFT JOIN Payments p ON o.order_id = p.order_id
WHERE p.payment_id IS NULL;

-- Each customer's total spend, ranked 
WITH CustomerSpend AS (
    SELECT c.customer_id, c.first_name,
           SUM(oi.quantity * oi.unit_price) AS total_spend
    FROM Customers c
    JOIN Orders o ON c.customer_id = o.customer_id
    JOIN OrderItems oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.first_name
)
SELECT customer_id, first_name, total_spend,
       RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM CustomerSpend;