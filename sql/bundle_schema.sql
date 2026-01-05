USE test_db;

CREATE TABLE PartsSupplier (
    id INTEGER PRIMARY KEY,
    supplier_name VARCHAR(255) NOT NULL
);

CREATE TABLE Category (
    id INTEGER PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE Customers (
    id INTEGER PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE Shippers (
    id INTEGER PRIMARY KEY,
    shipper_name VARCHAR(255) NOT NULL
);

CREATE TABLE Payments (
    id INTEGER PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    payment_date DATETIME DEFAULT GETDATE()
);


CREATE TABLE Parts (
    id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    part_name VARCHAR(255) NOT NULL,
    unit_price FLOAT NOT NULL DEFAULT 0,
    FOREIGN KEY (supplier_id) REFERENCES PartsSupplier(id)
);

CREATE TABLE Products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    labor_price FLOAT NOT NULL DEFAULT 0,
    current_stock INTEGER NOT NULL DEFAULT 0,
    production_time_hours INTEGER NOT NULL DEFAULT 1,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Category(id)
);

CREATE TABLE Addresses (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(255) NOT NULL,
    state VARCHAR(255),
    postal_code VARCHAR(20),
    country VARCHAR(255) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

CREATE TABLE Orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL DEFAULT GETDATE(), -- Poprawione: GETDATE() zamiast CURRENT_DATE
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- 3. Tabele łączące i zagnieżdżone

CREATE TABLE ProductElements (
    id INTEGER PRIMARY KEY,
    parts_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    UNIQUE (product_id, parts_id),
    FOREIGN KEY (parts_id) REFERENCES Parts(id),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

CREATE TABLE OrderDetails (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    discount INTEGER DEFAULT 0,
    UNIQUE (order_id, product_id),
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (order_id) REFERENCES Orders(id)
);

CREATE TABLE Shipments (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE,
    address_id INTEGER NOT NULL,
    payment_id INTEGER NOT NULL UNIQUE,
    shipper_id INTEGER NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(id),
    FOREIGN KEY (address_id) REFERENCES Addresses(id),
    FOREIGN KEY (payment_id) REFERENCES Payments(id),
    FOREIGN KEY (shipper_id) REFERENCES Shippers(id)
);

CREATE TABLE Reviews (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review VARCHAR(MAX),
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

CREATE TABLE CompanyOrders (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    order_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

USE test_db;
GO

-- 1. Zlicza koszt robocizny i wszystkich części potrzebnych do stworzenia konkretnego produktu
CREATE OR ALTER FUNCTION fn_CalculateProductionCost (@ProductId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalCost FLOAT;
    DECLARE @LaborCost FLOAT;
    DECLARE @PartsCost FLOAT;

    SELECT @LaborCost = labor_price FROM Products WHERE id = @ProductId;

    SELECT @PartsCost = SUM(p.unit_price * pe.quantity)
    FROM Parts p
    JOIN ProductElements pe ON p.id = pe.parts_id
    WHERE pe.product_id = @ProductId;

    SET @TotalCost = ISNULL(@LaborCost, 0) + ISNULL(@PartsCost, 0);

    RETURN @TotalCost;
END;
GO

-- 2. Wylicza końcową wartość zamówienia: koszt produkcji z narzutem 40%, pomniejszony o rabat
CREATE OR ALTER FUNCTION fn_CalculateOrderValue (@OrderId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalValue FLOAT;

    SELECT @TotalValue = SUM(
        (dbo.fn_CalculateProductionCost(od.product_id) * 1.4 * od.quantity) * (1.0 - (od.discount / 100.0))
    )
    FROM OrderDetails od
    WHERE od.order_id = @OrderId;

    RETURN ISNULL(@TotalValue, 0);
END;
GO

-- 3. Podlicza łączną kwotę, jaką dany klient wydał na wszystkie swoje zamówienia
CREATE OR ALTER FUNCTION fn_GetCustomerTotalSpent (@CustomerId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalSpent FLOAT;

    SELECT @TotalSpent = SUM(dbo.fn_CalculateOrderValue(o.id))
    FROM Orders o
    WHERE o.customer_id = @CustomerId;

    RETURN ISNULL(@TotalSpent, 0);
END;
GO

USE test_db;
GO

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
-- Pokazuje kto, jaki produkt i jak ocenił.
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

-- 1. Sprawdza czy produkt jest dostępny, wylicza cenę i szacuje czas oczekiwania (jeśli trzeba dorobić)
CREATE OR ALTER PROCEDURE sp_CheckAvailabilityAndCost
    @ProductId INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.name AS Produkt,
        dbo.fn_CalculateProductionCost(p.id) AS KosztProdukcji,
        (dbo.fn_CalculateProductionCost(p.id) * 1.4) AS CenaDlaKlienta,
        CASE
            WHEN p.current_stock >= @Quantity THEN 'Dostępny od ręki'
            ELSE 'Wymaga produkcji'
        END AS Status,
        CASE
            WHEN p.current_stock >= @Quantity THEN 0
            ELSE (@Quantity - p.current_stock) * p.production_time_hours
        END AS CzasOczekiwania_h
    FROM Products p
    WHERE p.id = @ProductId;
END;
GO

-- 2. Główna procedura zakupowa. Zdejmuje towar z magazynu, a jeśli brakuje – automatycznie zleca produkcję brakujących sztuk
CREATE OR ALTER PROCEDURE sp_PlaceOrder
    @CustomerId INT,
    @ProductId INT,
    @Quantity INT,
    @Discount INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStock INT;
        DECLARE @ProductionTime INT;
        DECLARE @MissingQuantity INT;
        DECLARE @OrderId INT;
        DECLARE @ProductionId INT;

        SELECT @CurrentStock = current_stock, @ProductionTime = production_time_hours
        FROM Products WHERE id = @ProductId;

        SELECT @OrderId = ISNULL(MAX(id), 0) + 1 FROM Orders;
        INSERT INTO Orders (id, customer_id, order_date) VALUES (@OrderId, @CustomerId, GETDATE());

        IF @CurrentStock >= @Quantity
        BEGIN
            UPDATE Products SET current_stock = current_stock - @Quantity WHERE id = @ProductId;
        END
        ELSE
        BEGIN
            SET @MissingQuantity = @Quantity - @CurrentStock;

            UPDATE Products SET current_stock = 0 WHERE id = @ProductId;

            SELECT @ProductionId = ISNULL(MAX(id), 0) + 1 FROM CompanyOrders;
            INSERT INTO CompanyOrders (id, product_id, quantity, order_date)
            VALUES (@ProductionId, @ProductId, @MissingQuantity, GETDATE());

            PRINT 'Zlecono produkcję brakującej ilości: ' + CAST(@MissingQuantity AS VARCHAR);
        END

        INSERT INTO OrderDetails (id, product_id, order_id, quantity, discount)
        VALUES (ISNULL((SELECT MAX(id) FROM OrderDetails),0)+1, @ProductId, @OrderId, @Quantity, @Discount);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 3. Zamyka zlecenie produkcyjne i dodaje gotowe produkty do stanu magazynowego
CREATE OR ALTER PROCEDURE sp_CompleteProduction
    @ProductionOrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ProdId INT;
        DECLARE @Qty INT;

        SELECT @ProdId = product_id, @Qty = quantity FROM CompanyOrders WHERE id = @ProductionOrderId;

        IF @ProdId IS NOT NULL
        BEGIN
            UPDATE Products SET current_stock = current_stock + @Qty WHERE id = @ProdId;
            DELETE FROM CompanyOrders WHERE id = @ProductionOrderId;
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Rejestruje klienta i jego adres w jednym rzucie (transakcja), żeby nie było niespójnych danych
CREATE OR ALTER PROCEDURE sp_RegisterCustomer
    @FirstName VARCHAR(255),
    @LastName VARCHAR(255),
    @Email VARCHAR(255),
    @AddressLine1 VARCHAR(255),
    @City VARCHAR(255),
    @PostalCode VARCHAR(20),
    @Country VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @NewCustomerId INT;
        SELECT @NewCustomerId = ISNULL(MAX(id), 0) + 1 FROM Customers;

        INSERT INTO Customers (id, first_name, last_name, email)
        VALUES (@NewCustomerId, @FirstName, @LastName, @Email);

        INSERT INTO Addresses (id, customer_id, address_line_1, city, postal_code, country)
        VALUES (ISNULL((SELECT MAX(id) FROM Addresses),0)+1, @NewCustomerId, @AddressLine1, @City, @PostalCode, @Country);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. Dodaje nowy produkt, ale wcześniej sprawdza, czy podana kategoria w ogóle istnieje
CREATE OR ALTER PROCEDURE sp_AddNewProduct
    @Name VARCHAR(255),
    @CategoryName VARCHAR(255),
    @LaborPrice FLOAT,
    @ProductionTimeHours INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CatId INT;
    SELECT @CatId = id FROM Category WHERE category_name = @CategoryName;

    IF @CatId IS NULL
    BEGIN
        PRINT 'Błąd: Brak kategorii o podanej nazwie.';
        RETURN;
    END

    DECLARE @NewProdId INT;
    SELECT @NewProdId = ISNULL(MAX(id), 0) + 1 FROM Products;

    INSERT INTO Products (id, name, labor_price, category_id, current_stock, production_time_hours)
    VALUES (@NewProdId, @Name, @LaborPrice, @CatId, 0, @ProductionTimeHours);
END;
GO

-- 6. Anuluje zamówienie, czyści powiązane tabele i zwraca towar z powrotem na magazyn
CREATE OR ALTER PROCEDURE sp_CancelOrder
    @OrderId INT,
    @Reason VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Orders WHERE id = @OrderId) THROW 50001, 'Brak zamówienia.', 1;

        UPDATE p
        SET p.current_stock = p.current_stock + od.quantity
        FROM Products p
        JOIN OrderDetails od ON p.id = od.product_id
        WHERE od.order_id = @OrderId;

        DELETE FROM Shipments WHERE order_id = @OrderId;
        DELETE FROM OrderDetails WHERE order_id = @OrderId;
        DELETE FROM Orders WHERE id = @OrderId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

USE test_db;
GO

-- 1. Podstawowa higiena danych. Blokuje zapis, jeśli ktoś wpisze bzdury (np. ujemną ilość lub rabat 500%).
CREATE OR ALTER TRIGGER trg_ValidateOrderDetails
ON OrderDetails
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE discount < 0 OR discount > 100)
    BEGIN
        RAISERROR('Rabat musi być w zakresie 0-100%.', 16, 1);
        ROLLBACK TRANSACTION;
    END

    IF EXISTS (SELECT 1 FROM inserted WHERE quantity <= 0)
    BEGIN
        RAISERROR('Ilość musi być dodatnia.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 2. "Bezpiecznik" logiczny. Jeśli jakakolwiek procedura spróbuje zdjąć więcej towaru niż mamy (robiąc minus), ten trigger cofnie całą operację.
CREATE OR ALTER TRIGGER trg_PreventNegativeStock
ON Products
AFTER UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE current_stock < 0)
    BEGIN
        RAISERROR('Stan magazynowy nie może być ujemny!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 3. Chroni przed przypadkowym usunięciem kategorii, która jest w użyciu. Jeśli są w niej produkty – usuwanie jest blokowane.
CREATE OR ALTER TRIGGER trg_ProtectCategoryDeletion
ON Category
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Products WHERE category_id IN (SELECT id FROM deleted))
    BEGIN
        RAISERROR('Nie można usunąć kategorii, która posiada przypisane produkty.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN
        DELETE FROM Category WHERE id IN (SELECT id FROM deleted);
    END
END;
GO

-- 4. Zabezpieczenie przed "literówkami" przy edycji cen (tzw. Fat Finger Check).
-- Jeśli cena nagle skoczy dwukrotnie lub spadnie prawie do zera, system uzna to za błąd i zablokuje zmianę.
CREATE OR ALTER TRIGGER trg_SafetyCheckPriceChange
ON Products
AFTER UPDATE
AS
BEGIN
    IF UPDATE(labor_price)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.id = d.id
                   WHERE i.labor_price > d.labor_price * 2.0 OR i.labor_price < d.labor_price * 0.1)
        BEGIN
            RAISERROR('Zbyt duża zmiana ceny robocizny. Wymagana autoryzacja managera.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

USE test_db;
GO

-- 1. Indeksy na kluczach obcych. Bez nich łączenie tabel (JOIN) przy zamówieniach i produktach byłoby bardzo wolne.
CREATE INDEX IX_Orders_CustomerId ON Orders(customer_id);
CREATE INDEX IX_OrderDetails_ProductId ON OrderDetails(product_id);
CREATE INDEX IX_OrderDetails_OrderId ON OrderDetails(order_id);
CREATE INDEX IX_ProductElements_PartsId ON ProductElements(parts_id);
CREATE INDEX IX_ProductElements_ProductId ON ProductElements(product_id);

-- 2. Indeksy na kolumnach z datą. Przyspieszają generowanie raportów za konkretne okresy (np. podsumowania roczne czy miesięczne).
CREATE INDEX IX_Orders_OrderDate ON Orders(order_date);
CREATE INDEX IX_CompanyOrders_OrderDate ON CompanyOrders(order_date);

-- 3. Indeks do filtrowania po kategorii. Ułatwia szybkie wyciąganie produktów z konkretnej grupy bez przeszukiwania całej tabeli.
CREATE INDEX IX_Products_CategoryId ON Products(category_id);
GO

USE test_db;
GO

-- 1. Definiowanie ról dla poszczególnych grup pracowników
CREATE ROLE Manager;         -- Kadra zarządzająca (tylko analizy)
CREATE ROLE WarehouseWorker; -- Magazynierzy (produkcja i stany magazynowe)
CREATE ROLE SalesPerson;     -- Dział handlowy (obsługa klienta i sprzedaż)
GO

-- 2. Przypisywanie uprawnień

----------------------------------------------------
-- ROLA: Manager
----------------------------------------------------
-- Manager ma widzieć wszystko (do raportów), ale nie może niczego zepsuć.
GRANT SELECT ON SCHEMA::dbo TO Manager;

-- Blokada edycji. Raporty mają odzwierciedlać stan faktyczny, manager nie powinien ręcznie modyfikować danych.
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Manager;

-- Dostęp do funkcji wyliczających wartości zamówień (potrzebne do analiz finansowych).
GRANT EXECUTE ON dbo.fn_CalculateOrderValue TO Manager;
GRANT EXECUTE ON dbo.fn_GetCustomerTotalSpent TO Manager;

----------------------------------------------------
-- ROLA: WarehouseWorker (Magazynier)
----------------------------------------------------
-- Musi widzieć zlecenia produkcyjne (co robić) i listę produktów.
GRANT SELECT ON CompanyOrders TO WarehouseWorker;
GRANT SELECT ON Products TO WarehouseWorker;
GRANT SELECT ON OrderDetails TO WarehouseWorker;

-- Po wyprodukowaniu towaru musi mieć możliwość zwiększenia stanu na magazynie.
GRANT UPDATE (current_stock) ON Products TO WarehouseWorker;

-- Najważniejsze uprawnienie: możliwość uruchomienia procedury kończącej produkcję.
GRANT EXECUTE ON OBJECT::sp_CompleteProduction TO WarehouseWorker;

----------------------------------------------------
-- ROLA: SalesPerson (Sprzedawca)
----------------------------------------------------
-- Pełna obsługa bazy klientów (dodawanie nowych, aktualizacja adresów).
GRANT INSERT, SELECT, UPDATE ON Customers TO SalesPerson;
GRANT INSERT, SELECT, UPDATE ON Addresses TO SalesPerson;

-- Musi widzieć listę produktów, żeby wiedzieć co sprzedaje.
GRANT SELECT ON Products TO SalesPerson;
GRANT EXECUTE ON dbo.fn_CalculateProductionCost TO SalesPerson; -- Potrzebne do wyceny dla klienta

-- Dostęp do procedur biznesowych – to są główne narzędzia pracy sprzedawcy.
GRANT EXECUTE ON OBJECT::sp_PlaceOrder TO SalesPerson;           -- Składanie zamówienia
GRANT EXECUTE ON OBJECT::sp_CheckAvailabilityAndCost TO SalesPerson; -- Sprawdzanie dostępności
GRANT EXECUTE ON OBJECT::sp_RegisterCustomer TO SalesPerson;     -- Rejestracja
GRANT EXECUTE ON OBJECT::sp_CancelOrder TO SalesPerson;          -- Anulowanie

-- Uprawnienia techniczne do tabel zamówień. Są konieczne, aby powyższe procedury mogły zapisać dane.
GRANT INSERT ON Orders TO SalesPerson;
GRANT INSERT ON OrderDetails TO SalesPerson;
GRANT DELETE ON OrderDetails TO SalesPerson; -- Wymagane przy anulowaniu zamówienia
GRANT DELETE ON Orders TO SalesPerson;

-- Ograniczenie dostępu: Sprzedawca nie musi znać cen zakupu poszczególnych śrubek od dostawców.
DENY SELECT ON PartsSupplier TO SalesPerson;
DENY SELECT ON Parts TO SalesPerson;
GO

USE test_db;
GO

-- RAPORT 1: Zestawienie kosztów produkcji z podziałem na lata, miesiące i grupy produktów.
-- Pozwala sprawdzić, która kategoria generuje największe koszty w danym okresie.
SELECT
    YEAR(co.order_date) AS Rok,
    MONTH(co.order_date) AS Miesiac,
    c.category_name AS GrupaProduktow,
    SUM(co.quantity) AS WyprodukowanaIlosc,
    SUM(co.quantity * dbo.fn_CalculateProductionCost(co.product_id)) AS CalkowityKosztProdukcji
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id
JOIN Category c ON p.category_id = c.id
GROUP BY YEAR(co.order_date), MONTH(co.order_date), c.category_name
ORDER BY Rok DESC, Miesiac DESC;
GO

-- RAPORT 2: Łączny stan magazynowy (fizyczny + w produkcji).
-- Pokazuje ile mamy towaru "na półce", a ile właśnie się produkuje, co daje pełny obraz dostępności.
SELECT
    p.name AS Produkt,
    p.current_stock AS StanNaMagazynie,
    ISNULL(SUM(co.quantity), 0) AS W_Trakcie_Produkcji,
    (p.current_stock + ISNULL(SUM(co.quantity), 0)) AS PrzewidywanyStanKoncowy
FROM Products p
LEFT JOIN CompanyOrders co ON p.id = co.product_id
GROUP BY p.name, p.current_stock;
GO

-- RAPORT 3: Historia zakupów klientów.
-- Wyświetla szczegóły zamówień, uwzględniając udzielone rabaty i ostateczną kwotę po obniżce.
SELECT
    c.first_name + ' ' + c.last_name AS Klient,
    o.order_date AS DataZamowienia,
    p.name AS Produkt,
    od.quantity AS Ilosc,
    od.discount AS PrzyznanyRabat_Procent,
    (dbo.fn_CalculateProductionCost(p.id) * 1.4 * od.quantity * (1 - od.discount/100.0)) AS WartoscPoRabacie
FROM Customers c
JOIN Orders o ON c.id = o.customer_id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
-- Możesz tu dodać WHERE c.id = X żeby filtrować klienta
ORDER BY o.order_date DESC;
GO

-- RAPORT 4: Analiza sprzedaży dla zarządu (tygodniowa).
-- Grupuje wyniki sprzedaży według kategorii i tygodni, pokazując łączny przychód.
SELECT
    c.category_name AS Kategoria,
    YEAR(o.order_date) AS Rok,
    DATEPART(week, o.order_date) AS TydzienRoku,
    SUM(od.quantity) AS SprzedanaIlosc,
    SUM(dbo.fn_CalculateOrderValue(o.id)) AS Przychod
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
JOIN Category c ON p.category_id = c.id
GROUP BY c.category_name, YEAR(o.order_date), DATEPART(week, o.order_date);
GO

-- RAPORT 5: Harmonogram produkcji.
-- Na podstawie pracochłonności produktu wylicza szacowaną datę zakończenia każdego zlecenia.
SELECT
    co.order_date AS DataZlecenia,
    p.name AS Produkt,
    co.quantity AS IloscDoWykonania,
    p.production_time_hours AS CzasJednostkowy_H,
    (co.quantity * p.production_time_hours) AS CalkowityCzasProdukcji_H,
    DATEADD(hour, (co.quantity * p.production_time_hours), co.order_date) AS SzacowanaDataZakonczenia
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id
WHERE co.quantity > 0 -- Tylko aktywne zlecenia
ORDER BY co.order_date;
GO