USE test_db;

-- 1. Słowniki i proste encje

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

-- 2. Główne encje produktowe

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
    margin FLOAT NOT NULL DEFAULT 1.4,
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
    order_date DATE NOT NULL DEFAULT GETDATE(),
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
    unit_price FLOAT NOT NULL DEFAULT 0,
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
-- (Ta funkcja pozostaje bez zmian - służy do wyceny "na teraz")
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

-- 2. Wylicza sugerowaną cenę sprzedaży (Koszt Produkcji * Marża Produktu)
CREATE OR ALTER FUNCTION fn_CalculateCurrentProductPrice (@ProductId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @ProductionCost FLOAT;
    DECLARE @Margin FLOAT;
    DECLARE @FinalPrice FLOAT;

    -- Pobierz aktualny koszt produkcji
    SET @ProductionCost = dbo.fn_CalculateProductionCost(@ProductId);

    -- Pobierz marżę przypisaną do konkretnego produktu
    SELECT @Margin = margin FROM Products WHERE id = @ProductId;

    -- Jeśli marża nie jest ustawiona, przyjmij bezpiecznie 1.0 (brak narzutu), choć schema wymusza NOT NULL
    SET @FinalPrice = ISNULL(@ProductionCost, 0) * ISNULL(@Margin, 1.0);

    RETURN @FinalPrice;
END;
GO

-- 3. Wylicza końcową wartość zamówienia na podstawie zapisanych cen
CREATE OR ALTER FUNCTION fn_CalculateOrderValue (@OrderId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalValue FLOAT;

    SELECT @TotalValue = SUM(
        (od.unit_price * od.quantity) * (1.0 - (od.discount / 100.0))
    )
    FROM OrderDetails od
    WHERE od.order_id = @OrderId;

    RETURN ISNULL(@TotalValue, 0);
END;
GO

-- 4. Podlicza łączną kwotę, jaką dany klient wydał
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


-- 5. Sprawdza, ile godzin pracy jest już zaplanowanych na dany dzień
CREATE OR ALTER FUNCTION fn_GetDailyProductionLoad (@Date DATE)
RETURNS INT
AS
BEGIN
    DECLARE @TotalHours INT;

    SELECT @TotalHours = SUM(co.quantity * p.production_time_hours)
    FROM CompanyOrders co
    JOIN Products p ON co.product_id = p.id
    WHERE co.order_date = @Date;

    RETURN ISNULL(@TotalHours, 0);
END;
GO

-- 6. Oblicza średnią ocenę produktu na podstawie opinii (Reviews)
-- Przydatne do wyświetlania "gwiazdek" przy produkcie w sklepie/katalogu.
CREATE OR ALTER FUNCTION fn_GetProductAverageRating (@ProductId INT)
RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @AvgRating DECIMAL(3, 2);

    SELECT @AvgRating = AVG(CAST(rating AS DECIMAL(3, 2)))
    FROM Reviews
    WHERE product_id = @ProductId;

    -- Jeśli brak opinii, zwracamy 0.00
    RETURN ISNULL(@AvgRating, 0.00);
END;
GO

-- 7. Sprawdza, czy całe zamówienie jest gotowe do wysyłki (Logistyka)
-- Zwraca 1 (Prawda), jeśli wszystkie produkty z zamówienia są w magazynie w wystarczającej ilości.
-- Zwraca 0 (Fałsz), jeśli brakuje choć jednego elementu.
CREATE OR ALTER FUNCTION fn_CheckOrderShippability (@OrderId INT)
RETURNS BIT
AS
BEGIN
    DECLARE @IsReady BIT = 1;

    -- Jeśli istnieje jakakolwiek pozycja w zamówieniu, której ilość przekracza stan magazynowy
    IF EXISTS (
        SELECT 1
        FROM OrderDetails od
        JOIN Products p ON od.product_id = p.id
        WHERE od.order_id = @OrderId
          AND od.quantity > p.current_stock
    )
    BEGIN
        SET @IsReady = 0;
    END

    RETURN @IsReady;
END;
GO

-- 8. Oblicza, na ile dni wystarczy zapasu magazynowego
-- Analizuje średnią sprzedaż z ostatnich 30 dni i dzieli przez to obecny stan magazynu.
-- Wynik '9999' oznacza, że produkt się nie sprzedaje (zapas wystarczy na zawsze).
CREATE OR ALTER FUNCTION fn_EstimateStockCoverageDays (@ProductId INT)
RETURNS INT
AS
BEGIN
    DECLARE @CurrentStock INT;
    DECLARE @SoldLast30Days INT;
    DECLARE @DailySalesAvg FLOAT;
    DECLARE @DaysLeft INT;

    SELECT @CurrentStock = current_stock 
    FROM Products 
    WHERE id = @ProductId;

    SELECT @SoldLast30Days = SUM(od.quantity)
    FROM OrderDetails od
    JOIN Orders o ON od.order_id = o.id
    WHERE od.product_id = @ProductId
      AND o.order_date >= DATEADD(DAY, -30, GETDATE());

    SET @SoldLast30Days = ISNULL(@SoldLast30Days, 0);

    IF @SoldLast30Days = 0
    BEGIN
        SET @DaysLeft = 9999;
    END
    ELSE
    BEGIN
        SET @DailySalesAvg = @SoldLast30Days / 30.0;
        
        SET @DaysLeft = CAST(@CurrentStock / @DailySalesAvg AS INT);
    END

    RETURN @DaysLeft;
END;
GO

-- 9. Sprawdza, ile sztuk danego produktu jest aktualnie "w produkcji"
-- Pomaga handlowcom ocenić, czy niski stan magazynowy zaraz się uzupełni.
CREATE OR ALTER FUNCTION fn_GetPendingProductionQuantity (@ProductId INT)
RETURNS INT
AS
BEGIN
    DECLARE @PendingQty INT;

    SELECT @PendingQty = SUM(quantity)
    FROM CompanyOrders
    WHERE product_id = @ProductId;

    RETURN ISNULL(@PendingQty, 0);
END;
GO

-- 10. Liczy dni od ostatniego zamówienia klienta 
-- Pozwala wyłapać klientów, którzy dawno nic nie kupili (np. > 90 dni) i wysłać im maila.
CREATE OR ALTER FUNCTION fn_GetDaysSinceLastCustomerOrder (@CustomerId INT)
RETURNS INT
AS
BEGIN
    DECLARE @LastDate DATE;
    DECLARE @DaysDiff INT;

    SELECT @LastDate = MAX(order_date)
    FROM Orders
    WHERE customer_id = @CustomerId;

    IF @LastDate IS NULL
        RETURN NULL; 

    SET @DaysDiff = DATEDIFF(DAY, @LastDate, GETDATE());

    RETURN @DaysDiff;
END;
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

-- 13. Raport kwartalny
CREATE OR ALTER VIEW QUARTERLY_SALES_REPORT AS
SELECT
    YEAR(o.order_date) AS SalesYear,
    DATEPART(QUARTER, o.order_date) AS SalesQuarter,
    p.name AS ProductName,
    SUM(od.quantity) AS TotalQuantity,
    SUM(od.quantity * od.unit_price * (1.0 - od.discount/100.0)) AS TotalRevenue
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
GROUP BY YEAR(o.order_date), DATEPART(QUARTER, o.order_date), p.name;
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
USE test_db;
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
    -- LIMIT MOCY PRZEROBOWYCH FABRYKI (160 roboczogodzin na dzień)
    DECLARE @DailyCapacityLimit INT = 160;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStock INT;
        DECLARE @ProductionTimePerUnit INT;
        DECLARE @MissingQuantity INT;
        DECLARE @OrderId INT;
        DECLARE @ProductionId INT;
        DECLARE @CurrentLoad INT;
        DECLARE @NewOrderLoad INT;

        SELECT @CurrentStock = current_stock,
               @ProductionTimePerUnit = production_time_hours
        FROM Products WHERE id = @ProductId;

        -- 1. Logika Magazyn vs Produkcja
        IF @CurrentStock >= @Quantity
        BEGIN
            -- Jest na stanie: tylko rezerwujemy
            UPDATE Products SET current_stock = current_stock - @Quantity WHERE id = @ProductId;
        END
        ELSE
        BEGIN
            -- Brak na stanie: trzeba wyprodukować
            SET @MissingQuantity = @Quantity - @CurrentStock;

            -- WYLICZENIE MOCY PRZEROBOWYCH
            SET @NewOrderLoad = @MissingQuantity * @ProductionTimePerUnit;
            SET @CurrentLoad = dbo.fn_GetDailyProductionLoad(CAST(GETDATE() AS DATE));

            IF (@CurrentLoad + @NewOrderLoad) > @DailyCapacityLimit
            BEGIN
                -- Odrzucamy zamówienie, jeśli fabryka jest przepełniona
                THROW 51000, 'Przekroczono dzienne moce przerobowe fabryki! Spróbuj złożyć zamówienie na inny termin lub mniejszą ilość.', 1;
            END

            -- Jeśli jest ok, zerujemy stan i zlecamy produkcję
            UPDATE Products SET current_stock = 0 WHERE id = @ProductId;

            SELECT @ProductionId = ISNULL(MAX(id), 0) + 1 FROM CompanyOrders;
            INSERT INTO CompanyOrders (id, product_id, quantity, order_date)
            VALUES (@ProductionId, @ProductId, @MissingQuantity, GETDATE());

            PRINT 'Zlecono produkcję brakującej ilości: ' + CAST(@MissingQuantity AS VARCHAR);
        END

        -- 2. Tworzenie zamówienia (jeśli przeszło walidację mocy)
        SELECT @OrderId = ISNULL(MAX(id), 0) + 1 FROM Orders;
        INSERT INTO Orders (id, customer_id, order_date) VALUES (@OrderId, @CustomerId, GETDATE());

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

USE test_db;
GO

-- 1. Podstawowa higiena danych. Blokuje zapis, jeśli ktoś wpisze bzdury (np. ujemną ilość lub rabat > 100%).
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

-- 2. Jeśli dodajesz produkt do zamówienia, ten trigger oblicza jego aktualną cenę
-- (koszt + marża) i zapisuje w tabeli. Dzięki temu późniejsze zmiany cennika nie psują starych zamówień.
CREATE OR ALTER TRIGGER trg_SetOrderDetailsPrice
ON OrderDetails
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Aktualizujemy tylko te wiersze, które właśnie weszły (inserted)
    -- i które mają cenę równą 0 (czyli system ma ją wyliczyć automatycznie).
    UPDATE od
    SET od.unit_price = dbo.fn_CalculateCurrentProductPrice(i.product_id)
    FROM OrderDetails od
    INNER JOIN inserted i ON od.id = i.id
    WHERE od.unit_price = 0;
END;
GO

-- 3. "Bezpiecznik" logiczny. Jeśli jakakolwiek procedura spróbuje zdjąć więcej towaru niż mamy (robiąc minus), ten trigger cofnie całą operację.
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

-- 4. Chroni przed przypadkowym usunięciem kategorii, która jest w użyciu. Jeśli są w niej produkty – usuwanie jest blokowane.
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

-- 5. Zabezpieczenie przed "literówkami" przy edycji cen (Fat Finger Check).
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
