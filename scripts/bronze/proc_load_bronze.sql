/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Tujuan:
    Memuat data mentah dari file CSV (sumber CRM dan ERP) ke tabel bronze.
    Setiap tabel dikosongkan (TRUNCATE) lalu diisi ulang (BULK INSERT),
    dengan pencatatan durasi per tabel dan total.

Cara pakai:
    EXEC bronze.load_bronze;

CATATAN:
    - Tabel bronze harus sudah dibuat (jalankan DDL bronze terlebih dahulu).
    - Path file dibaca oleh SERVER SQL Server, bukan komputer klien.
    - ROWTERMINATOR '0x0a' mengasumsikan file berakhiran LF. Jika CRLF,
      gunakan '0x0d0a'.
    - Layer bronze menyimpan data apa adanya: duplikat, NULL, dan format
      kotor tetap masuk dan dibersihkan di layer silver.

PERINGATAN:
    - TRUNCATE TABLE MENGHAPUS SEMUA DATA tabel sebelum load. Jika BULK INSERT
      gagal, tabel tersebut akan KOSONG dan tabel sesudahnya tidak ter-load.
    - Jangan dijalankan di database produksi.
    - Akun layanan SQL Server harus punya izin baca ke folder CSV.
    - Satu baris dengan tipe data tidak cocok menggagalkan seluruh BULK INSERT
      untuk tabel itu.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @set_time DATETIME, @end_time DATETIME,
            @batch_set_time DATETIME, @batch_end_time DATETIME;

    BEGIN TRY
        SET @batch_set_time = GETDATE();
        PRINT '=======================================';
        PRINT 'Loading Bronze Layer';
        PRINT '=======================================';

        PRINT '---------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting Data Into : bronze.crm_cust_info';
        BULK INSERT bronze.crm_cust_info
        FROM 'D:\Developer\SQL\source_crm\cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into : bronze.crm_prd_info';
        BULK INSERT bronze.crm_prd_info
        FROM 'D:\Developer\SQL\source_crm\prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into : bronze.crm_sales_details';
        BULK INSERT bronze.crm_sales_details
        FROM 'D:\Developer\SQL\source_crm\sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        PRINT '---------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting Data Into : bronze.erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12
        FROM 'D:\Developer\SQL\source_erp\CUST_AZ12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting Data Into : bronze.erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101
        FROM 'D:\Developer\SQL\source_erp\LOC_A101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        SET @set_time = GETDATE();
        PRINT '>> Truncating Table : bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into : bronze.erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'D:\Developer\SQL\source_erp\PX_CAT_G1V2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK
        );
        SET @end_time = GETDATE();
        PRINT '>> Load Duration : ' + CAST(DATEDIFF(millisecond, @set_time, @end_time) AS NVARCHAR) + ' ms';
        PRINT '>> ---------------------------------------';

        SET @batch_end_time = GETDATE();
        PRINT '=======================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '  - Total Load Duration : ' + CAST(DATEDIFF(millisecond, @batch_set_time, @batch_end_time) AS NVARCHAR) + ' ms';
        PRINT '=======================================';
    END TRY
    BEGIN CATCH
        PRINT '=======================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message : ' + ERROR_MESSAGE();
        PRINT 'Error Number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State   : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '=======================================';
        THROW;  -- lempar ulang error agar pemanggil tahu load gagal
    END CATCH
END;
GO

EXEC bronze.load_bronze;
