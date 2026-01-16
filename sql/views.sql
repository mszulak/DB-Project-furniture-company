USE test_db;
GO

-- 1. Raport sprzedaży tygodniowej.
CREATE OR ALTER VIEW WEEKLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    DATEPART(week, o.order_date) AS SalesWeek,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity,
    SUM(od.quantity * od.unit_price * (1.0 - od.discount/100.0)) AS TotalRevenue
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), DATEPART(week, o.order_date), p.name;
GO

-- 2. Raport sprzedaży miesięcznej.
CREATE OR ALTER VIEW MONTHLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    MONTH(o.order_date) AS SalesMonth,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity,
    SUM(od.quantity * od.unit_price * (1.0 - od.discount/100.0)) AS TotalRevenue
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), MONTH(o.order_date), p.name;
GO

-- 3. Raport sprzedaży rocznej.
CREATE OR ALTER VIEW YEARLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity,
    SUM(od.quantity * od.unit_price * (1.0 - od.discount/100.0)) AS TotalRevenue
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), p.name;
GO

-- 4. Fundament wyceny (Koszt jednostkowy BIEŻĄCY).
CREATE OR ALTER VIEW PRODUCT_PRODUCTION_COST_VIEW AS
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
GO

-- 5. "Przepis" na produkt (BOM).
CREATE OR ALTER VIEW PRODUCTS_PARTS_STRUCTURE_VIEW AS
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

-- 6. Główne zestawienie zamówień.
-- ZMIANA: Zamiast szacowanego kosztu produkcji, pokazujemy realną kwotę sprzedaży z zamówienia.
CREATE OR ALTER VIEW ORDERS_SUMMARY_VIEW AS
SELECT
    o.id AS OrderID,
    o.order_date,
    c.id AS CustomerID,
    c.first_name + ' ' + c.last_name AS CustomerName,
    p.name AS ProductName,
    od.quantity,
    od.unit_price AS BaseUnitTestPrice, -- Cena bazowa z momentu zakupu
    od.discount,
    (od.quantity * od.unit_price * (1.0 - od.discount/100.0)) AS FinalLineTotal -- Faktyczny przychód
FROM Orders o
JOIN Customers c ON o.customer_id = c.id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id;
GO

-- 7. Prosta historia zamówień.
CREATE OR ALTER VIEW CUSTOMER_ORDER_HISTORY_VIEW AS
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

-- 8. Cennik części u dostawców.
CREATE OR ALTER VIEW SUPPLIER_PARTS_COST_REPORT AS
SELECT
    ps.supplier_name,
    pr.part_name,
    pr.unit_price
FROM Parts pr
JOIN PartsSupplier ps ON pr.supplier_id = ps.id;
GO

-- 9. Ranking popularności (Best Sellers).
CREATE OR ALTER VIEW PRODUCT_SALES_VOLUME_VIEW AS
SELECT
    p.id AS ProductID,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalSold
FROM OrderDetails od
JOIN Products p ON od.product_id = p.id
GROUP BY p.id, p.name;
GO

-- 10. Plan produkcji (Internal Orders).
CREATE OR ALTER VIEW COMPANY_PRODUCTION_PLAN_VIEW AS
SELECT
    co.id AS CompanyOrderID,
    p.name AS ProductName,
    co.quantity
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id;
GO

-- 11. Status logistyczny.
CREATE OR ALTER VIEW SHIPMENTS_STATUS_VIEW AS
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

-- 12. Podgląd opinii.
CREATE OR ALTER VIEW PRODUCT_REVIEWS_VIEW AS
SELECT
    p.name AS ProductName,
    c.first_name + ' ' + c.last_name AS CustomerName,
    r.rating,
    r.review
FROM Reviews r
JOIN Products p ON r.product_id = p.id
JOIN Customers c ON r.customer_id = c.id;
GO