USE test_db;
GO

-- 1. Tworzenie ról bazodanowych
-- Rola dla Kadry Zarządczej (tylko odczyt raportów i analiz)
CREATE ROLE Manager;

-- Rola dla Pracownika Produkcji/Magazynu (zarządzanie stanem, podgląd zamówień produkcyjnych)
CREATE ROLE WarehouseWorker;

-- Rola dla Sprzedawcy (obsługa klientów, składanie zamówień)
CREATE ROLE SalesPerson;
GO

-- 2. Nadawanie uprawnień (GRANT)

----------------------------------------------------
-- UPRAWNIENIA: Manager
----------------------------------------------------
-- Manager może czytać wszystko (potrzebne do raportów)
GRANT SELECT ON SCHEMA::dbo TO Manager;
-- Ale nie pozwalamy mu nic zmieniać (bezpieczeństwo danych historycznych)
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Manager;
-- Może korzystać z funkcji analitycznych (VIP, koszty)
GRANT EXECUTE ON dbo.fn_CalculateOrderValue TO Manager;
GRANT EXECUTE ON dbo.fn_GetCustomerTotalSpent TO Manager;

----------------------------------------------------
-- UPRAWNIENIA: WarehouseWorker
----------------------------------------------------
-- Musi widzieć co wyprodukować (CompanyOrders) i stany magazynowe
GRANT SELECT ON CompanyOrders TO WarehouseWorker;
GRANT SELECT ON Products TO WarehouseWorker;
GRANT SELECT ON OrderDetails TO WarehouseWorker;

-- Musi aktualizować stan magazynowy po wyprodukowaniu
GRANT UPDATE (current_stock) ON Products TO WarehouseWorker;

-- KLUCZOWE: Uprawnienie do procedury zamykania produkcji
GRANT EXECUTE ON OBJECT::sp_CompleteProduction TO WarehouseWorker;

----------------------------------------------------
-- UPRAWNIENIA: SalesPerson
----------------------------------------------------
-- Sprzedawca dodaje/edytuje klientów i adresy
GRANT INSERT, SELECT, UPDATE ON Customers TO SalesPerson;
GRANT INSERT, SELECT, UPDATE ON Addresses TO SalesPerson;

-- Sprzedawca widzi produkty i ceny
GRANT SELECT ON Products TO SalesPerson;
GRANT EXECUTE ON dbo.fn_CalculateProductionCost TO SalesPerson; -- Żeby widział wyceny

-- KLUCZOWE: Uprawnienia do procedur biznesowych (te, które masz w pliku procedures.sql)
GRANT EXECUTE ON OBJECT::sp_PlaceOrder TO SalesPerson;           -- Składanie zamówienia
GRANT EXECUTE ON OBJECT::sp_CheckAvailabilityAndCost TO SalesPerson; -- Sprawdzanie ceny
GRANT EXECUTE ON OBJECT::sp_RegisterCustomer TO SalesPerson;     -- Dodawanie klienta
GRANT EXECUTE ON OBJECT::sp_CancelOrder TO SalesPerson;          -- Anulowanie

-- Uprawnienia do tabel pod spodem (niezbędne, by procedury działały na koncie usera)
GRANT INSERT ON Orders TO SalesPerson;
GRANT INSERT ON OrderDetails TO SalesPerson;
GRANT DELETE ON OrderDetails TO SalesPerson; -- Potrzebne do anulowania
GRANT DELETE ON Orders TO SalesPerson;       -- Potrzebne do anulowania

-- Sprzedawca nie powinien widzieć kosztów części od dostawców (Tajemnica firmy)
DENY SELECT ON PartsSupplier TO SalesPerson;
DENY SELECT ON Parts TO SalesPerson;
GO