USE test_db;

CREATE TABLE PartsSupplier (
    id INTEGER PRIMARY KEY,
    supplier_name VARCHAR(255) NOT NULL
);

CREATE TABLE Category (
    id INTEGER PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE Customers (
    id INTEGER PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE Shippers (
    id INTEGER PRIMARY KEY,
    shipper_name VARCHAR(255) NOT NULL
);

CREATE TABLE Payments (
    id INTEGER PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    payment_date DATETIME DEFAULT GETDATE() 
);


CREATE TABLE Parts (
    id INTEGER PRIMARY KEY,
    supplier_id INTEGER NOT NULL,
    part_name VARCHAR(255) NOT NULL,
    unit_price FLOAT NOT NULL DEFAULT 0,
    FOREIGN KEY (supplier_id) REFERENCES PartsSupplier(id)
);

CREATE TABLE Products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    labor_price FLOAT NOT NULL DEFAULT 0,
    current_stock INTEGER NOT NULL DEFAULT 0,
    production_time_hours INTEGER NOT NULL DEFAULT 1,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Category(id)
);

CREATE TABLE Addresses (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(255) NOT NULL,
    state VARCHAR(255),
    postal_code VARCHAR(20),
    country VARCHAR(255) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

CREATE TABLE Orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL DEFAULT GETDATE(), -- Poprawione: GETDATE() zamiast CURRENT_DATE
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

-- 3. Tabele łączące i zagnieżdżone

CREATE TABLE ProductElements (
    id INTEGER PRIMARY KEY,
    parts_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    UNIQUE (product_id, parts_id),
    FOREIGN KEY (parts_id) REFERENCES Parts(id),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

CREATE TABLE OrderDetails (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    discount INTEGER DEFAULT 0,
    UNIQUE (order_id, product_id),
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (order_id) REFERENCES Orders(id)
);

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

CREATE TABLE Reviews (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review VARCHAR(MAX), 
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (customer_id) REFERENCES Customers(id)
);

CREATE TABLE CompanyOrders (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    order_date DATE NOT NULL DEFAULT GETDATE(), 
    FOREIGN KEY (product_id) REFERENCES Products(id)
);