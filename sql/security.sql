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
-- Manager może czytać wszystko (potrzebne do raportów finansowych i magazynowych)
GRANT SELECT ON SCHEMA::dbo TO Manager;
-- Ale nie pozwalamy mu nic zmieniać (bezpieczeństwo danych historycznych)
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO Manager;

----------------------------------------------------
-- UPRAWNIENIA: WarehouseWorker
----------------------------------------------------
-- Musi widzieć co wyprodukować (CompanyOrders) i co wysłać (Shipments)
GRANT SELECT ON CompanyOrders TO WarehouseWorker;
GRANT SELECT ON Shipments TO WarehouseWorker;
GRANT SELECT ON OrderDetails TO WarehouseWorker;

-- Musi aktualizować stan magazynowy po wyprodukowaniu lub wydaniu towaru
GRANT UPDATE (current_stock) ON Products TO WarehouseWorker;

-- Może odczytywać procedury planowania, ale niekoniecznie je modyfikować
GRANT EXECUTE ON OBJECT::sp_GetProductionPlan TO WarehouseWorker;

----------------------------------------------------
-- UPRAWNIENIA: SalesPerson
----------------------------------------------------
-- Sprzedawca dodaje klientów i adresy
GRANT INSERT, SELECT, UPDATE ON Customers TO SalesPerson;
GRANT INSERT, SELECT, UPDATE ON Addresses TO SalesPerson;

-- Sprzedawca składa zamówienia (korzysta z procedury, która robi INSERT do Orders/Details)
GRANT EXECUTE ON OBJECT::sp_CreateCustomerOrder TO SalesPerson;
-- Musi mieć uprawnienie do INSERT w tabelach, na których operuje procedura,
-- chyba że procedura ma "WITH EXECUTE AS OWNER", ale załóżmy standardowy model:
GRANT INSERT ON Orders TO SalesPerson;
GRANT INSERT ON OrderDetails TO SalesPerson;
GRANT SELECT ON Products TO SalesPerson; -- Musi widzieć co sprzedaje

-- Sprzedawca nie powinien widzieć kosztów produkcji (Parts, Suppliers), tylko cenę końcową
DENY SELECT ON PartsSupplier TO SalesPerson;
DENY SELECT ON Parts TO SalesPerson;
GO