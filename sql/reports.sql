USE test_db;
GO

-- RAPORT 1: Zestawienie kosztów produkcji z podziałem na lata, miesiące i grupy produktów.
SELECT
    YEAR(co.order_date) AS Rok,
    MONTH(co.order_date) AS Miesiac,
    c.category_name AS GrupaProduktow,
    SUM(co.quantity) AS WyprodukowanaIlosc,
    SUM(co.quantity * dbo.fn_CalculateProductionCost(co.product_id)) AS CalkowityKosztProdukcji
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id
JOIN Category c ON p.category_id = c.id
GROUP BY YEAR(co.order_date), MONTH(co.order_date), c.category_name
ORDER BY Rok DESC, Miesiac DESC;
GO

-- RAPORT 2: Łączny stan magazynowy (fizyczny + w produkcji).
SELECT
    p.name AS Produkt,
    p.current_stock AS StanNaMagazynie,
    ISNULL(SUM(co.quantity), 0) AS W_Trakcie_Produkcji,
    (p.current_stock + ISNULL(SUM(co.quantity), 0)) AS PrzewidywanyStanKoncowy
FROM Products p
LEFT JOIN CompanyOrders co ON p.id = co.product_id
GROUP BY p.name, p.current_stock;
GO

-- RAPORT 3: Historia zakupów klientów.
SELECT
    c.first_name + ' ' + c.last_name AS Klient,
    o.order_date AS DataZamowienia,
    p.name AS Produkt,
    od.quantity AS Ilosc,
    od.unit_price AS CenaBazowaWChwiliZakupu, -- Dodatkowa informacja
    od.discount AS PrzyznanyRabat_Procent,
    (od.unit_price * od.quantity * (1.0 - od.discount/100.0)) AS WartoscKoncowa
FROM Customers c
JOIN Orders o ON c.id = o.customer_id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
ORDER BY o.order_date DESC;
GO

-- RAPORT 4: Analiza sprzedaży (tygodniowa).
SELECT
    c.category_name AS Kategoria,
    YEAR(o.order_date) AS Rok,
    DATEPART(week, o.order_date) AS TydzienRoku,
    SUM(od.quantity) AS SprzedanaIlosc,
    SUM(dbo.fn_CalculateOrderValue(o.id)) AS Przychod
FROM Orders o
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id
JOIN Category c ON p.category_id = c.id
GROUP BY c.category_name, YEAR(o.order_date), DATEPART(week, o.order_date);
GO

-- RAPORT 5: Harmonogram produkcji.
SELECT
    co.order_date AS DataZlecenia,
    p.name AS Produkt,
    co.quantity AS IloscDoWykonania,
    p.production_time_hours AS CzasJednostkowy_H,
    (co.quantity * p.production_time_hours) AS CalkowityCzasProdukcji_H,
    DATEADD(hour, (co.quantity * p.production_time_hours), co.order_date) AS SzacowanaDataZakonczenia
FROM CompanyOrders co
JOIN Products p ON co.product_id = p.id
WHERE co.quantity > 0
ORDER BY co.order_date;
GO