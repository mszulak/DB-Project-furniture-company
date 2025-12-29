-- =========================================================
-- 1. TABELE SŁOWNIKOWE I NIEZALEŻNE (Tworzymy jako pierwsze)
-- =========================================================

-- Słownik dostawców (firmy, od których kupujemy części)
CREATE TABLE PartsSupplier (
    id INTEGER PRIMARY KEY,
    supplier_name VARCHAR(255) NOT NULL
);

-- Kategorie produktów (np. Electronics, Furniture)
CREATE TABLE Category (
    id INTEGER PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE -- Nazwa kategorii nie może się powtarzać
);

-- Baza klientów. Email jest unikalny (służy jako login/identyfikator)
CREATE TABLE Customers (
    id INTEGER PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

-- Firmy kurierskie (Shippers) realizujące dostawy
CREATE TABLE Shippers (
    id INTEGER PRIMARY KEY,
    shipper_name VARCHAR(255) NOT NULL
);

-- Rejestr płatności. Transaction_id to unikalny numer z banku/bramki płatniczej.
CREATE TABLE Payments (
    id INTEGER PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    payment_date DATETIME DEFAULT GETDATE() -- Data wbija się automatycznie
);

-- =========================================================
-- 2. TABELE ZALEŻNE (Korzystają z kluczy obcych tabel wyżej)
-- =========================================================

-- Magazyn części (surowców). Unit_price to cena zakupu od dostawcy.
CREATE TABLE Parts (
    id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    part_name VARCHAR(255) NOT NULL,
    unit_price FLOAT NOT NULL DEFAULT 0,
    FOREIGN KEY (supplier_id) REFERENCES PartsSupplier(id)
);

-- Gotowe produkty na sprzedaż.
-- SKU (Stock Keeping Unit) to unikalny kod magazynowy produktu.
-- Labor_price to koszt robocizny potrzebny do złożenia produktu.
CREATE TABLE Products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    labor_price FLOAT NOT NULL DEFAULT 0,
    sku INTEGER NOT NULL UNIQUE,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Category(id)
);

-- Adresy klientów (jeden klient może mieć wiele adresów, np. dom, praca)
CREATE TABLE Addresses (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(255) NOT NULL,
    state VARCHAR(255),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(255) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- Nagłówki zamówień (kto kupił i kiedy)
CREATE TABLE Orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- =========================================================
-- 3. TABELE ŁĄCZĄCE I GŁĘBOKO ZAGNIEŻDŻONE
-- =========================================================

-- Tabela BOM (Bill of Materials) - definicja z czego składa się produkt.
-- Mówi nam: "Do produktu X potrzebujesz 4 sztuki części Y".
CREATE TABLE ProductElements (
    id INTEGER PRIMARY KEY,
    parts_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    UNIQUE (product_id, parts_id), -- Zapobiega dodaniu tej samej części dwa razy do jednego produktu
    FOREIGN KEY (parts_id) REFERENCES Parts(id),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

-- Szczegóły zamówienia (pozycje na fakturze).
-- Mówi nam: "W zamówieniu nr 123 klient kupił 2 sztuki produktu ABC".
CREATE TABLE OrderDetails (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    discount INTEGER DEFAULT 0,
    UNIQUE (order_id, product_id), -- Zapobiega dublowaniu tego samego produktu w jednym zamówieniu
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (order_id) REFERENCES Orders(id)
);

-- Logistyka (Wysyłka).
-- Kluczowe są tu UNIQUE przy order_id i payment_id - wymuszają relację 1:1.
-- Jedno zamówienie = jedna wysyłka = jedna płatność.
CREATE TABLE Shipments (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL UNIQUE,
    address_id INTEGER NOT NULL,
    payment_id INTEGER NOT NULL UNIQUE,
    shipper_id INTEGER NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(id),
    FOREIGN KEY (address_id) REFERENCES Addresses(id),
    FOREIGN KEY (payment_id) REFERENCES Payments(id),
    FOREIGN KEY (shipper_id) REFERENCES Shippers(id)
);

-- Opinie klientów. CHECK pilnuje, żeby ocena była w skali 1-5.
CREATE TABLE Reviews (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review VARCHAR(MAX),
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- Wewnętrzne zamówienia firmy (np. na potrzeby własne/produkcyjne)
CREATE TABLE CompanyOrders (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    order_date DATE NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);





-- Widok 1: Katalog produktów z nazwami kategorii
CREATE VIEW v_ProductCatalog AS
SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.sku,
    p.labor_price,
    c.category_name
FROM Products p
JOIN Category c ON p.category_id = c.id;
GO

-- Widok 2: Pełne szczegóły zamówień (Kto, co i kiedy)
CREATE VIEW v_OrderDetailsFull AS
SELECT
    o.id AS order_id,
    o.order_date,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    p.name AS product_name,
    od.quantity,
    od.discount
FROM Orders o
JOIN Customers c ON o.customer_id = c.id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id;
GO

-- Widok 3: Status wysyłek dla logistyki
CREATE VIEW v_ShipmentStatus AS
SELECT
    s.order_id,
    pay.transaction_id,
    pay.payment_date,
    sh.shipper_name,
    a.city,
    a.country
FROM Shipments s
JOIN Payments pay ON s.payment_id = pay.id
JOIN Shippers sh ON s.shipper_id = sh.id
JOIN Addresses a ON s.address_id = a.id;
GO
--4
-- Łączy: Zamówienie -> Klienta -> Szczegóły -> Produkt
CREATE VIEW v_Sales_Summary AS
SELECT
    o.id AS order_id,
    o.order_date,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    p.name AS product_name,
    p.sku,
    od.quantity,
    od.discount
FROM Orders o
JOIN Customers c ON o.customer_id = c.id
JOIN OrderDetails od ON o.id = od.order_id
JOIN Products p ON od.product_id = p.id;
GO
--5
-- Łączy: Wysyłkę -> Adres -> Kuriera -> Płatność
CREATE VIEW v_Logistics_Data AS
SELECT
    s.order_id,
    pay.transaction_id,
    pay.payment_date,
    sh.shipper_name,
    a.address_line_1,
    a.city,
    a.postal_code,
    a.country
FROM Shipments s
JOIN Payments pay ON s.payment_id = pay.id
JOIN Shippers sh ON s.shipper_id = sh.id
JOIN Addresses a ON s.address_id = a.id;
GO
--6
-- Łączy: Produkt -> Elementy -> Części -> Dostawcę
-- To jest kluczowe, żeby wiedzieć, co zamówić od dostawców
CREATE VIEW v_Production_BOM AS
SELECT
    prod.name AS product_name,
    pe.quantity AS parts_needed,
    part.part_name,
    part.unit_price AS part_cost,
    sup.supplier_name
FROM ProductElements pe
JOIN Products prod ON pe.product_id = prod.id
JOIN Parts part ON pe.parts_id = part.id
JOIN PartsSupplier sup ON part.supplier_id = sup.id;
GO

--7
-- Łączy: Opinię -> Produkt -> Klienta
CREATE VIEW v_Customer_Reviews AS
SELECT
    p.name AS product_name,
    c.first_name AS reviewer_name,
    r.rating,
    r.review
FROM Reviews r
JOIN Products p ON r.product_id = p.id
JOIN Customers c ON r.customer_id = c.id;
GO