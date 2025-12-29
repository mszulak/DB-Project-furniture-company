USE test_db;
GO

-- 1. KLUCZOWA PROCEDURA: Składanie zamówienia (z logiką produkcyjną)
-- Realizuje wymaganie: "składanie zamówienia na produkty, których aktualnie nie ma w magazynie"
-- oraz "planowanie elementów do produkcji".
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

        -- Zmienne pomocnicze
        DECLARE @CurrentStock INT;
        DECLARE @ProductionTime INT;
        DECLARE @MissingQuantity INT;
        DECLARE @OrderId INT;
        DECLARE @OrderDetailId INT;
        DECLARE @ProductionId INT;

        -- Pobierz aktualny stan i czas produkcji
        SELECT
            @CurrentStock = current_stock,
            @ProductionTime = production_time_hours
        FROM Products
        WHERE id = @ProductId;

        -- Generuj ID dla zamówienia (zakładamy brak IDENTITY, liczymy ręcznie)
        SELECT @OrderId = ISNULL(MAX(id), 0) + 1 FROM Orders;

        -- 1. Tworzymy nagłówek zamówienia
        INSERT INTO Orders (id, customer_id, order_date)
        VALUES (@OrderId, @CustomerId, GETDATE());

        -- 2. Logika magazynowa
        IF @CurrentStock >= @Quantity
        BEGIN
            -- SCENARIUSZ A: Mamy wystarczająco towaru
            UPDATE Products
            SET current_stock = current_stock - @Quantity
            WHERE id = @ProductId;

            PRINT 'Zamówienie zrealizowane z magazynu.';
        END
        ELSE
        BEGIN
            -- SCENARIUSZ B: Brakuje towaru -> Zlecenie produkcji
            SET @MissingQuantity = @Quantity - @CurrentStock;

            -- Zabieramy wszystko co jest w magazynie (jeśli cokolwiek jest)
            UPDATE Products
            SET current_stock = 0
            WHERE id = @ProductId;

            -- Generuj ID dla zlecenia produkcyjnego
            SELECT @ProductionId = ISNULL(MAX(id), 0) + 1 FROM CompanyOrders;

            -- Dodajemy wpis do kolejki produkcji (CompanyOrders)
            -- To realizuje "planowanie elementów do produkcji" [cite: 10]
            INSERT INTO CompanyOrders (id, product_id, quantity, order_date)
            VALUES (@ProductionId, @ProductId, @MissingQuantity, GETDATE());

            PRINT 'Brak towaru. Zlecono produkcję sztuk: ' + CAST(@MissingQuantity AS VARCHAR);
            PRINT 'Szacowany czas produkcji (godziny): ' + CAST((@MissingQuantity * @ProductionTime) AS VARCHAR);
        END

        -- 3. Dodajemy detale zamówienia (klient zamawia X, niezależnie skąd to weźmiemy)
        SELECT @OrderDetailId = ISNULL(MAX(id), 0) + 1 FROM OrderDetails;

        INSERT INTO OrderDetails (id, product_id, order_id, quantity, discount)
        VALUES (@OrderDetailId, @ProductId, @OrderId, @Quantity, @Discount);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- Rzuć błędem wyżej
        THROW;
    END CATCH
END;
GO

-- 2. PROCEDURA: Zakończenie produkcji (Uzupełnienie magazynu)
-- Symuluje "wejście" towaru na magazyn po wyprodukowaniu.
-- Wymagane do raportowania "bieżących stanów magazynowych".
CREATE OR ALTER PROCEDURE sp_CompleteProduction
    @ProductionOrderId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ProdId INT;
        DECLARE @Qty INT;

        -- Pobierz co było produkowane
        SELECT @ProdId = product_id, @Qty = quantity
        FROM CompanyOrders
        WHERE id = @ProductionOrderId;

        IF @ProdId IS NOT NULL
        BEGIN
            -- Zwiększ stan magazynowy
            UPDATE Products
            SET current_stock = current_stock + @Qty
            WHERE id = @ProdId;

            -- Można tu usunąć zlecenie z CompanyOrders lub oznaczyć jako zrealizowane.
            -- W tym prostym schemacie usuwamy, traktując tabelę jako "kolejkę aktywną".
            DELETE FROM CompanyOrders WHERE id = @ProductionOrderId;

            PRINT 'Produkcja zakończona. Magazyn uzupełniony o ' + CAST(@Qty AS VARCHAR) + ' szt.';
        END
        ELSE
        BEGIN
            PRINT 'Nie znaleziono takiego zlecenia produkcyjnego.';
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 3. PROCEDURA: Szybka wycena i czas realizacji (dla klienta)
-- Realizuje wymaganie "oszacować czas na wykonanie produktu".
CREATE OR ALTER PROCEDURE sp_CheckAvailabilityAndCost
    @ProductId INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.name AS Produkt,
        p.labor_price AS CenaBazowa,
        CASE
            WHEN p.current_stock >= @Quantity THEN 'Dostępny od ręki'
            ELSE 'Wymaga produkcji'
        END AS Status,
        CASE
            WHEN p.current_stock >= @Quantity THEN 0
            ELSE (@Quantity - p.current_stock) * p.production_time_hours
        END AS SzacowanyCzasProdukcji_Godziny
    FROM Products p
    WHERE p.id = @ProductId;
END;
GO