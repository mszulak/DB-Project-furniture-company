USE test_db;

-- ==========================================================
-- 1. Klienci
-- ==========================================================
CREATE TABLE Klienci (
    id_klienta INT IDENTITY(1,1) PRIMARY KEY,
    imie NVARCHAR(50) NOT NULL,
    nazwisko NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    telefon NVARCHAR(20),
    data_rejestracji DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ==========================================================
-- 2. Produkty
-- ==========================================================
CREATE TABLE Produkty (
    id_produktu INT IDENTITY(1,1) PRIMARY KEY,
    nazwa NVARCHAR(100) NOT NULL,
    cena DECIMAL(10,2) NOT NULL CHECK (cena >= 0),
    stan_magazynowy INT NOT NULL DEFAULT 0 CHECK (stan_magazynowy >= 0),
    opis NVARCHAR(255)
);
GO

-- ==========================================================
-- 3. Zamowienia
-- ==========================================================
CREATE TABLE Zamowienia (
    id_zamowienia INT IDENTITY(1,1) PRIMARY KEY,
    id_klienta INT NOT NULL,
    data_zamowienia DATETIME2 DEFAULT SYSDATETIME(),
    status NVARCHAR(20) NOT NULL DEFAULT 'NOWE',
    CONSTRAINT FK_Zamowienia_Klienci FOREIGN KEY (id_klienta)
        REFERENCES Klienci(id_klienta)
        ON DELETE CASCADE
);
GO

-- ==========================================================
-- 4. PozycjeZamowienia
-- ==========================================================
CREATE TABLE PozycjeZamowienia (
    id_pozycji INT IDENTITY(1,1) PRIMARY KEY,
    id_zamowienia INT NOT NULL,
    id_produktu INT NOT NULL,
    ilosc INT NOT NULL CHECK (ilosc > 0),
    cena_jednostkowa DECIMAL(10,2) NOT NULL CHECK (cena_jednostkowa >= 0),
    CONSTRAINT FK_Pozycje_Zamowienia FOREIGN KEY (id_zamowienia)
        REFERENCES Zamowienia(id_zamowienia)
        ON DELETE CASCADE,
    CONSTRAINT FK_Pozycje_Produkty FOREIGN KEY (id_produktu)
        REFERENCES Produkty(id_produktu)
);
GO

-- ==========================================================
-- 5. Platnosci
-- ==========================================================
CREATE TABLE Platnosci (
    id_platnosci INT IDENTITY(1,1) PRIMARY KEY,
    id_zamowienia INT NOT NULL UNIQUE,
    metoda NVARCHAR(30) NOT NULL,
    kwota DECIMAL(10,2) NOT NULL CHECK (kwota >= 0),
    status NVARCHAR(20) NOT NULL DEFAULT 'OCZEKUJĄCA',
    data_platnosci DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Platnosci_Zamowienia FOREIGN KEY (id_zamowienia)
        REFERENCES Zamowienia(id_zamowienia)
        ON DELETE CASCADE
);
GO

-- ==========================================================
-- Indeksy dodatkowe
-- ==========================================================
CREATE INDEX IX_Produkty_Nazwa ON Produkty(nazwa);
CREATE INDEX IX_Zamowienia_Klient ON Zamowienia(id_klienta);
CREATE INDEX IX_Pozycje_Zamowienia ON PozycjeZamowienia(id_zamowienia);
GO
