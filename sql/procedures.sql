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