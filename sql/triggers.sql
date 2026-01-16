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