USE test_db;

INSERT INTO Addresses (id, customer_id, address_line_1, address_line_2, city, state, postal_code, country) VALUES
(1, 1, '123 Maple Street', 'Apt 4B', 'New York', 'NY', '10001', 'USA'),
(2, 2, '456 Oak Avenue', NULL, 'Los Angeles', 'CA', '90001', 'USA'),
(3, 3, '789 Pine Lane', 'Suite 100', 'Chicago', 'IL', '60601', 'USA'),
(4, 4, '12 Victoria Road', NULL, 'London', NULL, 'SW1A 1AA', 'UK'),
(5, 5, '34 Rue de Rivoli', 'Floor 2', 'Paris', NULL, '75001', 'France'),
(6, 6, '56 King Street', NULL, 'Toronto', 'ON', 'M5V 1J2', 'Canada'),
(7, 7, '89 George Street', 'Level 5', 'Sydney', 'NSW', '2000', 'Australia'),
(8, 8, '101 Friedrichstraße', NULL, 'Berlin', 'BE', '10117', 'Germany'),
(9, 9, '202 Shibuya Crossing', 'Unit 301', 'Tokyo', 'Tokyo', '150-0002', 'Japan'),
(10, 10, '303 Marine Drive', NULL, 'Mumbai', 'MH', '400001', 'India'),
(11, 11, '404 Orchard Road', 'B1-05', 'Singapore', NULL, '238823', 'Singapore'),
(12, 12, '505 Paseo de la Reforma', NULL, 'Mexico City', 'CDMX', '06500', 'Mexico'),
(13, 13, '606 Avenida Paulista', 'Conjunto 12', 'Sao Paulo', 'SP', '01311-000', 'Brazil'),
(14, 14, '707 Sheikh Zayed Road', NULL, 'Dubai', 'Dubai', '00000', 'UAE'),
(15, 15, '808 Long Street', NULL, 'Cape Town', 'WC', '8001', 'South Africa'),
(16, 16, '909 Damrak', 'Front Office', 'Amsterdam', 'NH', '1012 LG', 'Netherlands'),
(17, 17, '111 Via Roma', NULL, 'Rome', 'RM', '00184', 'Italy'),
(18, 18, '222 Kungsgatan', '3tr', 'Stockholm', 'AB', '111 35', 'Sweden'),
(19, 19, '333 Collins Street', NULL, 'Melbourne', 'VIC', '3000', 'Australia'),
(20, 20, '444 Market Street', 'Apt 202', 'San Francisco', 'CA', '94105', 'USA');