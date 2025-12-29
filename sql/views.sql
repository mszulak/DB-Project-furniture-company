-- Views
-- TODO dodac viewsy ze sprzedazy w ujęciu tygodniowym, rocznym

-- 1. Raport kosztów produkcji jednostkowej
CREATE VIEW PRODUCT_PRODUCTION_COST_VIEW AS
SELECT 
    p.id AS ProductID,
    p.name AS ProductName,
    p.labor_price AS LaborCost,
    SUM(pe.quantity * pr.unit_price) AS PartsCost,
    p.labor_price + SUM(pe.quantity * pr.unit_price) AS TotalProductionCost
FROM Products p
JOIN ProductElements pe ON p.id = pe.product_id
JOIN Parts pr ON pe.parts_id = pr.id
GROUP BY p.id, p.name, p.labor_price;

GO -- signals the end of statement

-- 2. Struktura poroduktu z jakich części i w jakiej ilości się składa
CREATE VIEW PRODUCTS_PARTS_STRUCTURE_VIEW AS
SELECT
    p.id AS ProductID,
    p.name AS ProductName,
    pr.part_name,
    pe.quantity,
    pr.unit_price,
    pe.quantity * pr.unit_price AS PartTotalCost
FROM Products p
JOIN ProductElements pe ON p.id = pe.product_id
JOIN Parts pr ON pe.parts_id = pr.id;

GO

-- 3. Zbiorcze zestawienie zamówień klientów
CREATE VIEW ORDERS_SUMMARY_VIEW AS
SELECT
    o.id AS OrderID,
    o.order_date,
    c.id AS CustomerID,
    c.first_name + ' ' + c.last_name AS CustomerName,
    p.name AS ProductName,
    od.quantity,
    (od.quantity * v.TotalProductionCost) AS EstimatedOrderCost
FROM Orders o
JOIN Customers c ON o.customer_id = c.id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
JOIN PRODUCT_PRODUCTION_COST_VIEW v ON p.id = v.ProductID;

GO

-- 4. Historia zamówień jednego klienta (do filtracji po customer_id)
CREATE VIEW CUSTOMER_ORDER_HISTORY_VIEW AS
SELECT
    c.id AS CustomerID,
    c.first_name,
    c.last_name,
    o.id AS OrderID,
    o.order_date,
    p.name AS ProductName,
    od.quantity
FROM Customers c
JOIN Orders o ON c.id = o.customer_id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id;

GO

-- 5. Raport kosztów części wg dostawców
CREATE VIEW SUPPLIER_PARTS_COST_REPORT AS
SELECT
    ps.supplier_name,
    pr.part_name,
    pr.unit_price
FROM Parts pr
JOIN PartsSupplier ps ON pr.supplier_id = ps.id;

GO

-- 6. Ilość sprzedanych produktów - ranking sprzedazy
CREATE VIEW PRODUCT_SALES_VOLUME_VIEW AS
SELECT
    p.id AS ProductID,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalSold
FROM OrderDetails od
JOIN Products p ON od.product_id = p.id
GROUP BY p.id, p.name;

GO

-- 7. Sprzedaż produktów w ujęciu miesięcznym
-- TODO Dodac w ujeciu tygodniowym rocznym
CREATE VIEW MONTHLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    MONTH(o.order_date) AS SalesMonth,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), MONTH(o.order_date), p.name;

GO

-- 8. Produkty zaplanowane do produkcji zamówienia wewnętrzne
CREATE VIEW COMPANY_PRODUCTION_PLAN_VIEW AS
SELECT
    co.id AS CompanyOrderID,
    p.name AS ProductName,
    co.quantity
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id;

GO

-- 9. Status wysyłek
CREATE VIEW SHIPMENTS_STATUS_VIEW AS
SELECT
    s.id AS ShipmentID,
    o.id AS OrderID,
    sh.shipper_name,
    a.city,
    a.country
FROM Shipments s
JOIN Orders o ON s.order_id = o.id
JOIN Shippers sh ON s.shipper_id = sh.id
JOIN Addresses a ON s.address_id = a.id;

GO

-- 10. Opinie klientów o produktach
CREATE VIEW PRODUCT_REVIEWS_VIEW AS
SELECT
    p.name AS ProductName,
    c.first_name + ' ' + c.last_name AS CustomerName
FROM Reviews r
JOIN Products p ON r.product_id = p.id
JOIN Customers c ON r.customer_id = c.id;


