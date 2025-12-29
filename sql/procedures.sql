USE test_db;
GO

-- 1. Sprawdzanie dostępności i kosztów (Dla Klienta/Sprzedawcy)
CREATE OR ALTER PROCEDURE sp_CheckAvailabilityAndCost
    @ProductId INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.name AS Produkt,
        dbo.fn_CalculateProductionCost(p.id) AS KosztProdukcji,
        (dbo.fn_CalculateProductionCost(p.id) * 1.4) AS CenaDlaKlienta, -- Symulacja marży
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

-- 2. Składanie zamówienia (Główna logika biznesowa - automatyczna produkcja)
-- Realizuje - zamawianie towaru, którego nie ma
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

        -- Generowanie ID (bo brak IDENTITY w schemacie)
        SELECT @OrderId = ISNULL(MAX(id), 0) + 1 FROM Orders;
        INSERT INTO Orders (id, customer_id, order_date) VALUES (@OrderId, @CustomerId, GETDATE());

        IF @CurrentStock >= @Quantity
        BEGIN
            -- Scenariusz A: Jest towar
            UPDATE Products SET current_stock = current_stock - @Quantity WHERE id = @ProductId;
            PRINT 'Zrealizowano z magazynu.';
        END
        ELSE
        BEGIN
            -- Scenariusz B: Brak towaru -> Zlecenie produkcji
            SET @MissingQuantity = @Quantity - @CurrentStock;

            -- Zabieramy resztki z magazynu
            UPDATE Products SET current_stock = 0 WHERE id = @ProductId;

            -- Dodajemy zlecenie produkcyjne
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

-- 3. Zakończ produkcję (Magazyn)
-- Realizuje - aktualizacja stanów
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
            PRINT 'Produkcja zakończona. Stan magazynowy zaktualizowany.';
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4. Dodaj Klienta (CRUD - Administracja)
-- Odpowiednik 'dodaj_firme' z przykładowego PDFa
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
        PRINT 'Klient dodany.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. Dodaj Produkt (CRUD - Administracja)
-- UWAGA: Dostosowano do nowego schematu (brak kolumny SKU!)
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

    PRINT 'Produkt dodany: ' + @Name;
END;
GO

-- 6. Anuluj Zamówienie (Logika zwrotu towaru)
-- To jest "feature premium". Anulowanie zamówienia zwraca towar na magazyn.
CREATE OR ALTER PROCEDURE sp_CancelOrder
    @OrderId INT,
    @Reason VARCHAR(255) -- Opcjonalnie do logów
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM Orders WHERE id = @OrderId) THROW 50001, 'Brak zamówienia.', 1;

        -- 1. Zwrot towaru na magazyn (automatycznie)
        UPDATE p
        SET p.current_stock = p.current_stock + od.quantity
        FROM Products p
        JOIN OrderDetails od ON p.id = od.product_id
        WHERE od.order_id = @OrderId;

        -- 2. Usuwanie powiązań (najpierw tabele zależne)
        DELETE FROM Shipments WHERE order_id = @OrderId; -- Jeśli była wysyłka
        DELETE FROM OrderDetails WHERE order_id = @OrderId;
        DELETE FROM Orders WHERE id = @OrderId;

        PRINT 'Zamówienie anulowane. Towar zwrócony na stan magazynowy.';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO