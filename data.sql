USE test_db;
GO

-- ==========================================================
-- Klienci
-- ==========================================================
INSERT INTO Klienci (imie, nazwisko, email, telefon)
VALUES
('Jan', 'Kowalski', 'jan.kowalski@example.com', '600111222'),
('Anna', 'Nowak', 'anna.nowak@example.com', '600333444'),
('Piotr', 'Zieliński', 'piotr.zielinski@example.com', '600555666');
GO

-- ==========================================================
-- Produkty
-- ==========================================================
INSERT INTO Produkty (nazwa, cena, stan_magazynowy, opis)
VALUES
('Laptop Lenovo X1', 5400.00, 10, 'Ultrabook 14" i7'),
('Smartfon Samsung S23', 3800.00, 25, 'Ekran AMOLED 6.1"'),
('Monitor Dell 27"', 1200.00, 5, 'Rozdzielczość QHD'),
('Mysz Logitech MX', 250.00, 50, 'Bezprzewodowa, ergonomiczna'),
('Klawiatura Keychron K2', 400.00, 20, 'Mechaniczna, bezprzewodowa');
GO

-- ==========================================================
-- Zamówienia
-- ==========================================================
INSERT INTO Zamowienia (id_klienta, status)
VALUES
(1, 'NOWE'),
(2, 'OPŁACONE'),
(3, 'WYSŁANE');
GO

-- ==========================================================
-- Pozycje zamówień
-- ==========================================================
INSERT INTO PozycjeZamowienia (id_zamowienia, id_produktu, ilosc, cena_jednostkowa)
VALUES
(1, 1, 1, 5400.00),   -- Jan kupił 1 laptopa
(1, 4, 2, 250.00),    -- + 2 myszy
(2, 2, 1, 3800.00),   -- Anna kupiła 1 smartfon
(3, 3, 1, 1200.00),   -- Piotr kupił 1 monitor
(3, 5, 1, 400.00);    -- + 1 klawiaturę
GO

-- ==========================================================
-- Płatności
-- ==========================================================
INSERT INTO Platnosci (id_zamowienia, metoda, kwota, status)
VALUES
(1, 'PRZELEW', 5900.00, 'OCZEKUJĄCA'),
(2, 'KARTA', 3800.00, 'ZAKOŃCZONA'),
(3, 'BLIK', 1600.00, 'ZAKOŃCZONA');
GO
