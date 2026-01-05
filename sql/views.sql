USE test_db;
GO

-- 1. Raport sprzedaży tygodniowej.
-- Pozwala sprawdzić sezonowość (np. w którym tygodniu roku sprzedaż skacze w górę).
CREATE OR ALTER VIEW WEEKLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    DATEPART(week, o.order_date) AS SalesWeek, -- Zwraca numer tygodnia (1-52)
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), DATEPART(week, o.order_date), p.name;
GO

-- 2. Raport sprzedaży miesięcznej.
-- Klasyczne zestawienie wyników, najczęściej używane do rozliczeń okresowych.
CREATE OR ALTER VIEW MONTHLY_SALES_REPORT AS
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

-- 3. Raport sprzedaży rocznej.
-- Widok "z lotu ptaka" – pokazuje ogólne trendy i najlepiej sprzedające się towary w skali roku.
CREATE OR ALTER VIEW YEARLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), p.name;
GO

-- 4. Fundament wyceny (Koszt jednostkowy).
-- Zlicza koszt wszystkich części + robociznę dla jednej sztuki. Inne widoki korzystają z tego wyniku.
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

-- 5. "Przepis" na produkt (BOM - Bill of Materials).
-- Pokazuje listę składników potrzebnych do zbudowania produktu wraz z ich cenami.
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
-- Łączy dane klienta z zamówieniem i – co ważne – wyliczonym kosztem produkcji (z widoku nr 4).
CREATE OR ALTER VIEW ORDERS_SUMMARY_VIEW AS
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

-- 7. Prosta historia zamówień.
-- Widok pomocniczy, np. do wyświetlania listy zakupów w panelu klienta.
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
-- Szybki podgląd, ile kosztują półprodukty i od kogo je bierzemy.
CREATE OR ALTER VIEW SUPPLIER_PARTS_COST_REPORT AS
SELECT
    ps.supplier_name,
    pr.part_name,
    pr.unit_price
FROM Parts pr
JOIN PartsSupplier ps ON pr.supplier_id = ps.id;
GO

-- 9. Ranking popularności (Best Sellers).
-- Zlicza ile sztuk danego produktu sprzedaliśmy łącznie w całej historii.
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
-- To jest "lista zadań" dla hali produkcyjnej – co trzeba dorobić i w jakiej ilości.
CREATE OR ALTER VIEW COMPANY_PRODUCTION_PLAN_VIEW AS
SELECT
    co.id AS CompanyOrderID,
    p.name AS ProductName,
    co.quantity
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id;
GO

-- 11. Status logistyczny.
-- Łączy zamówienie z firmą kurierską i adresem docelowym.
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
-- Pokazuje kto i jaki produkt ocenił.
CREATE OR ALTER VIEW PRODUCT_REVIEWS_VIEW AS
SELECT
    p.name AS ProductName,
    c.first_name + ' ' + c.last_name AS CustomerName,
    r.rating,  -- Zakładam, że masz takie kolumny w tabeli Reviews
    r.comment  -- Warto dodać treść opinii, jeśli tabela ją posiada
FROM Reviews r
JOIN Products p ON r.product_id = p.id
JOIN Customers c ON r.customer_id = c.id;
GO