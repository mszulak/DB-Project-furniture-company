USE test_db;
GO

-- 1. Indeksy na kluczach obcych. Bez nich łączenie tabel (JOIN) przy zamówieniach i produktach byłoby bardzo wolne.
CREATE INDEX IX_Orders_CustomerId ON Orders(customer_id);
CREATE INDEX IX_OrderDetails_ProductId ON OrderDetails(product_id);
CREATE INDEX IX_OrderDetails_OrderId ON OrderDetails(order_id);
CREATE INDEX IX_ProductElements_PartsId ON ProductElements(parts_id);
CREATE INDEX IX_ProductElements_ProductId ON ProductElements(product_id);

-- 2. Indeksy na kolumnach z datą. Przyspieszają generowanie raportów za konkretne okresy (np. podsumowania roczne czy miesięczne).
CREATE INDEX IX_Orders_OrderDate ON Orders(order_date);
CREATE INDEX IX_CompanyOrders_OrderDate ON CompanyOrders(order_date);

-- 3. Indeks do filtrowania po kategorii. Ułatwia szybkie wyciąganie produktów z konkretnej grupy bez przeszukiwania całej tabeli.
CREATE INDEX IX_Products_CategoryId ON Products(category_id);
GO