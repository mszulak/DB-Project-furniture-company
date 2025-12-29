USE test_db;
GO

-- 1. Trigger: Walidacja poprawności rabatu (0-100%) oraz dodatniej ilości towaru
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

-- 2. Trigger: Blokada ustawienia ujemnego stanu magazynowego
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

-- 3. Trigger: Blokada usunięcia kategorii, do której przypisane są produkty
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

-- 4. Trigger: Monitorowanie i blokada drastycznych zmian cen robocizny (>100% wzrostu lub spadek do <10%)
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