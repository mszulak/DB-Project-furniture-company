USE test_db;
GO

-- 1. Sprawdzanie dostępności i kosztów (ZREFAKTORYZOWANA)
-- Teraz używa funkcji fn_CalculateProductionCost!
CREATE OR ALTER PROCEDURE sp_CheckAvailabilityAndCost
    @ProductId INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Wywołujemy funkcję wewnątrz zapytania
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

-- 2. Składanie zamówienia (Bez zmian - operuje na ilościach)
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
            PRINT 'Zrealizowano z magazynu.';
        END
        ELSE
        BEGIN
            SET @MissingQuantity = @Quantity - @CurrentStock;
            UPDATE Products SET current_stock = 0 WHERE id = @ProductId;

            SELECT @ProductionId = ISNULL(MAX(id), 0) + 1 FROM CompanyOrders;
            INSERT INTO CompanyOrders (id, product_id, quantity, order_date)
            VALUES (@ProductionId, @ProductId, @MissingQuantity, GETDATE());

            PRINT 'Zlecono produkcję: ' + CAST(@MissingQuantity AS VARCHAR) + ' szt.';
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

-- 3. Zamykanie produkcji (Bez zmian)
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
            PRINT 'Produkcja zakończona.';
        END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO