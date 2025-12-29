USE master;
GO

-- 1. Zabij wszystkie połączenia do bazy
DECLARE @kill VARCHAR(8000) = '';

SELECT @kill = @kill + 'KILL ' + CONVERT(VARCHAR(5), session_id) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('test_db');

IF (@kill <> '')
    EXEC(@kill);
GO

-- 2. Drop bazy, jeśli istnieje
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'test_db')
BEGIN
    ALTER DATABASE test_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE test_db;
END
GO

-- 3. Tworzenie nowej bazy od zera
CREATE DATABASE test_db;
GO
