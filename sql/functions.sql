USE test_db;
GO

-- 1. Funkcja: Obliczanie całkowitego kosztu produkcji produktu
-- Realizuje wymaganie: "określić koszt wyprodukowania" (robocizna + części)
CREATE OR ALTER FUNCTION fn_CalculateProductionCost (@ProductId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalCost FLOAT;
    DECLARE @LaborCost FLOAT;
    DECLARE @PartsCost FLOAT;

    -- 1. Pobierz koszt robocizny z tabeli Products
    SELECT @LaborCost = labor_price FROM Products WHERE id = @ProductId;

    -- 2. Oblicz koszt części (Suma: cena części * ilość w produkcie)
    SELECT @PartsCost = SUM(p.unit_price * pe.quantity)
    FROM Parts p
    JOIN ProductElements pe ON p.id = pe.parts_id
    WHERE pe.product_id = @ProductId;

    -- Zabezpieczenie przed NULL
    SET @TotalCost = ISNULL(@LaborCost, 0) + ISNULL(@PartsCost, 0);

    RETURN @TotalCost;
END;
GO

-- 2. Funkcja: Obliczanie wartości zamówienia (Przychód)
-- Potrzebne do analityki sprzedaży. Zakładamy marżę 40% na koszt produkcji.
CREATE OR ALTER FUNCTION fn_CalculateOrderValue (@OrderId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalValue FLOAT;

    -- Sumujemy: (Koszt Produkcji * 1.4 marży) * Ilość * (1 - Rabat%)
    SELECT @TotalValue = SUM(
        (dbo.fn_CalculateProductionCost(od.product_id) * 1.4 * od.quantity) * (1.0 - (od.discount / 100.0))
    )
    FROM OrderDetails od
    WHERE od.order_id = @OrderId;

    RETURN ISNULL(@TotalValue, 0);
END;
GO

-- 3. Funkcja: Całkowite wydatki klienta (LTV - Lifetime Value)
-- Pozwala wyłonić kluczowych klientów (VIP)
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