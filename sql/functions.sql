USE test_db;
GO

-- 1. Funkcja: Obliczanie całkowitego kosztu produkcji produktu (robocizna + części)
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

-- 2. Funkcja: Obliczanie wartości zamówienia (koszt produkcji + marża - rabat)
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

-- 3. Funkcja: Obliczanie sumy wydatków danego klienta
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