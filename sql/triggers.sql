USE test_db;
GO

-- 1. TRIGGER: Walidacja szczegółów zamówienia
-- Realizuje "warunki integralności" - biznesowe zasady poprawności danych.
CREATE OR ALTER TRIGGER trg_ValidateOrderDetails
ON OrderDetails
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Sprawdzenie 1: Czy rabat jest w widełkach 0-100%?
    -- Realizuje wymaganie "przydzielenie jednostkowego rabatu" , ale pilnuje, by był sensowny.
    IF EXISTS (SELECT 1 FROM inserted WHERE discount < 0 OR discount > 100)
    BEGIN
        RAISERROR('Błąd: Rabat musi mieścić się w przedziale 0-100%.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Sprawdzenie 2: Czy ilość jest dodatnia?
    IF EXISTS (SELECT 1 FROM inserted WHERE quantity <= 0)
    BEGIN
        RAISERROR('Błąd: Ilość zamawianego towaru musi być większa od 0.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 2. TRIGGER: Zabezpieczenie stanu magazynowego
-- To jest "bezpiecznik". Nawet jak ktoś ręcznie zrobi UPDATE Products,
-- trigger nie pozwoli ustawić ujemnego stanu.
CREATE OR ALTER TRIGGER trg_PreventNegativeStock
ON Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Jeśli po aktualizacji stan (current_stock) jest mniejszy od 0 -> Cofnij
    IF EXISTS (SELECT 1 FROM inserted WHERE current_stock < 0)
    BEGIN
        RAISERROR('Błąd krytyczny: Stan magazynowy nie może być ujemny!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- 3. TRIGGER: Automatyczna data modyfikacji (opcjonalny bajer)
-- Jak ktoś zmieni status płatności, to chcemy mieć pewność, że data płatności jest aktualna
CREATE OR ALTER TRIGGER trg_UpdatePaymentDate
ON Payments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Jeśli wstawiono rekord bez daty (NULL), ustawiamy GETDATE()
    -- W Twoim schemacie jest DEFAULT, ale to zabezpiecza przed jawnym wpisaniem NULLa
    UPDATE p
    SET payment_date = GETDATE()
    FROM Payments p
    JOIN inserted i ON p.id = i.id
    WHERE i.payment_date IS NULL;
END;
GO