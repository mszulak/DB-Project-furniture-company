USE test_db;
GO

-- 1. Indeksy dla kluczy obcych (przyspieszają JOINy)
-- Niezbędne przy łączeniu zamówień z klientami i produktami
CREATE INDEX IX_Orders_CustomerId ON Orders(customer_id);
CREATE INDEX IX_OrderDetails_ProductId ON OrderDetails(product_id);
CREATE INDEX IX_OrderDetails_OrderId ON OrderDetails(order_id);
CREATE INDEX IX_ProductElements_PartsId ON ProductElements(parts_id);
CREATE INDEX IX_ProductElements_ProductId ON ProductElements(product_id);

-- 2. Indeksy dla filtrowania po dacie (niezbędne do raportów okresowych)
-- Realizuje wsparcie dla raportów "ujętych kwartalnie, miesięcznie oraz rocznie"
CREATE INDEX IX_Orders_OrderDate ON Orders(order_date);
CREATE INDEX IX_CompanyOrders_OrderDate ON CompanyOrders(order_date); -- Dla planowania produkcji

-- 3. Indeks dla filtrowania po kategorii (analiza grup produktów)
-- Realizuje wsparcie dla raportów "dla poszczególnych grup produktów"
CREATE INDEX IX_Products_CategoryId ON Products(category_id);
GO