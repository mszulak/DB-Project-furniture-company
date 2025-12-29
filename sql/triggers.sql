USE test_db;
GO

-- 1. Walidacja rabatu i ilości (Business Logic)
-- Realizuje - warunki integralności
CREATE OR ALTER TRIGGER trg_ValidateOrderDetails
ON OrderDetails
AFTER INSERT, UPDATE
AS
BEGIN
    -- Rabat max 100%
    IF EXISTS (SELECT 1 FROM inserted WHERE discount < 0 OR discount > 100)
    BEGIN
        RAISERROR('Rabat musi być w zakresie 0-100%.', 16, 1);
        ROLLBACK TRANSACTION;
    END

    -- Ilość musi być dodatnia
    IF EXISTS (SELECT 1 FROM inserted WHERE quantity <= 0)
    BEGIN
        RAISERROR('Ilość musi być dodatnia.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- 2. Blokada ujemnego stanu magazynowego (Safety Net)
-- Kluczowe dla spójności danych magazynowych
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

-- 3. Blokada usuwania kategorii z produktami (Foreign Key Guard)
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

-- 4. Monitorowanie drastycznych zmian cen (Audyt)
-- Dodatkowy bajer, którego nie było w PDFie, a robi wrażenie
CREATE OR ALTER TRIGGER trg_SafetyCheckPriceChange
ON Products
AFTER UPDATE
AS
BEGIN
    IF UPDATE(labor_price)
    BEGIN
        -- Jeśli cena zmienia się o >100% w górę lub spada do <10%
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.id = d.id
                   WHERE i.labor_price > d.labor_price * 2.0 OR i.labor_price < d.labor_price * 0.1)
        BEGIN
            RAISERROR('Zbyt duża zmiana ceny robocizny. Wymagana autoryzacja managera.', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO