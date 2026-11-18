/*
=============================================================
Membuat Database dan Schema
=============================================================
Tujuan Script:
    Script ini membuat database baru bernama 'DataWarehouse'. Jika database
    tersebut sudah ada, database akan dihapus lalu dibuat ulang. Setelah itu,
    script membuat tiga schema: 'bronze', 'silver', dan 'gold'.

PERINGATAN:
    Menjalankan script ini akan menghapus seluruh database 'DataWarehouse'
    jika sudah ada. Semua data di dalamnya akan dihapus PERMANEN.
    Lanjutkan dengan hati-hati dan pastikan sudah ada backup
    sebelum menjalankan script ini.
=============================================================
*/

USE master;

--Menghapus database 'DataWarehouse' jika sudah ada
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
	ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE DataWarehouse;
END;
GO

--Membuat database 'DataWarehouse'
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

--Membuat schema
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;

