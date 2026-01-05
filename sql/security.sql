USE test_db;
GO

-- 1. Definiowanie ról dla poszczególnych grup pracowników
CREATE ROLE Manager;         -- Kadra zarządzająca (tylko analizy)
CREATE ROLE WarehouseWorker; -- Magazynierzy (produkcja i stany magazynowe)
CREATE ROLE SalesPerson;     -- Dział handlowy (obsługa klienta i sprzedaż)
GO

-- 2. Przypisywanie uprawnień

----------------------------------------------------
-- ROLA: Manager
----------------------------------------------------
-- Manager ma widzieć wszystko (do raportów), ale nie może niczego zepsuć.
GRANT SELECT ON SCHEMA::dbo TO Manager;

-- Blokada edycji. Raporty mają odzwierciedlać stan faktyczny, manager nie powinien ręcznie modyfikować danych.
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Manager;

-- Dostęp do funkcji wyliczających wartości zamówień (potrzebne do analiz finansowych).
GRANT EXECUTE ON dbo.fn_CalculateOrderValue TO Manager;
GRANT EXECUTE ON dbo.fn_GetCustomerTotalSpent TO Manager;

----------------------------------------------------
-- ROLA: WarehouseWorker (Magazynier)
----------------------------------------------------
-- Musi widzieć zlecenia produkcyjne (co robić) i listę produktów.
GRANT SELECT ON CompanyOrders TO WarehouseWorker;
GRANT SELECT ON Products TO WarehouseWorker;
GRANT SELECT ON OrderDetails TO WarehouseWorker;

-- Po wyprodukowaniu towaru musi mieć możliwość zwiększenia stanu na magazynie.
GRANT UPDATE (current_stock) ON Products TO WarehouseWorker;

-- Najważniejsze uprawnienie: możliwość uruchomienia procedury kończącej produkcję.
GRANT EXECUTE ON OBJECT::sp_CompleteProduction TO WarehouseWorker;

----------------------------------------------------
-- ROLA: SalesPerson (Sprzedawca)
----------------------------------------------------
-- Pełna obsługa bazy klientów (dodawanie nowych, aktualizacja adresów).
GRANT INSERT, SELECT, UPDATE ON Customers TO SalesPerson;
GRANT INSERT, SELECT, UPDATE ON Addresses TO SalesPerson;

-- Musi widzieć listę produktów, żeby wiedzieć co sprzedaje.
GRANT SELECT ON Products TO SalesPerson;
GRANT EXECUTE ON dbo.fn_CalculateProductionCost TO SalesPerson; -- Potrzebne do wyceny dla klienta

-- Dostęp do procedur biznesowych – to są główne narzędzia pracy sprzedawcy.
GRANT EXECUTE ON OBJECT::sp_PlaceOrder TO SalesPerson;           -- Składanie zamówienia
GRANT EXECUTE ON OBJECT::sp_CheckAvailabilityAndCost TO SalesPerson; -- Sprawdzanie dostępności
GRANT EXECUTE ON OBJECT::sp_RegisterCustomer TO SalesPerson;     -- Rejestracja
GRANT EXECUTE ON OBJECT::sp_CancelOrder TO SalesPerson;          -- Anulowanie

-- Uprawnienia techniczne do tabel zamówień. Są konieczne, aby powyższe procedury mogły zapisać dane.
GRANT INSERT ON Orders TO SalesPerson;
GRANT INSERT ON OrderDetails TO SalesPerson;
GRANT DELETE ON OrderDetails TO SalesPerson; -- Wymagane przy anulowaniu zamówienia
GRANT DELETE ON Orders TO SalesPerson;

-- Ograniczenie dostępu: Sprzedawca nie musi znać cen zakupu poszczególnych śrubek od dostawców.
DENY SELECT ON PartsSupplier TO SalesPerson;
DENY SELECT ON Parts TO SalesPerson;
GO