USE test_db;
GO

-- 1. Koszt produkcji (Części + Robocizna)
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

    RETURN ISNULL(@LaborCost, 0) + ISNULL(@PartsCost, 0);
END;
GO

-- 2. Wartość zamówienia (do raportów sprzedażowych)
CREATE OR ALTER FUNCTION fn_CalculateOrderValue (@OrderId INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @TotalValue FLOAT;
    -- Zakładamy, że cena sprzedaży to Koszt * 1.4 (marża)
    SELECT @TotalValue = SUM(
        (dbo.fn_CalculateProductionCost(od.product_id) * 1.4) * od.quantity - od.discount
    )
    FROM OrderDetails od
    WHERE od.order_id = @OrderId;

    RETURN ISNULL(@TotalValue, 0);
END;
GO