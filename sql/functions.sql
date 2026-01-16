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

-- 3. ZMODYFIKOWANA: Wylicza końcową wartość zamówienia na podstawie zapisanych cen
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