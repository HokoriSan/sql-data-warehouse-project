/*
===============================================================================
Script: Load Data CSV ke Layer Bronze
===============================================================================
Tujuan:
    Memuat data mentah dari file CSV (sumber CRM dan ERP) ke tabel bronze
    menggunakan BULK INSERT. Tabel dikosongkan dulu (TRUNCATE) agar tidak
    terjadi data ganda saat script dijalankan ulang.

CATATAN:
    - Tabel bronze harus sudah dibuat (jalankan DDL bronze terlebih dahulu).
    - Path file dibaca oleh SERVER SQL Server, BUKAN oleh komputer klien.
      Path D:\... harus ada di mesin tempat SQL Server berjalan.
    - Jumlah dan urutan kolom CSV harus sama dengan tabel tujuan.
    - FIRSTROW = 2 melewati baris header.
    - ROWTERMINATOR '0x0a' mengasumsikan file berakhiran LF. Jika file
      berakhiran CRLF, gunakan '0x0d0a'.
    - Data dimuat apa adanya. Duplikat, NULL, dan format kotor tetap masuk
      dan baru dibersihkan di layer silver.

PERINGATAN:
    - TRUNCATE TABLE MENGHAPUS SEMUA DATA di tabel sebelum load.
      Jangan dijalankan di database produksi.
    - Akun layanan SQL Server harus punya izin baca ke folder CSV. Jika
      tidak, akan muncul error "Operating system error code 5 (Access denied)".
    - Jika SQL Server berjalan di Docker, VM, atau server lain, path D:\
      di komputermu tidak akan terbaca. Salin file ke mesin server dulu.
    - Satu baris yang tipe datanya tidak cocok (misalnya teks di kolom INT)
      akan menggagalkan seluruh perintah BULK INSERT tabel itu.
===============================================================================
*/

-- ===== CRM =====

-- Informasi pelanggan
TRUNCATE TABLE bronze.crm_cust_info;
BULK INSERT bronze.crm_cust_info
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

-- Informasi produk
TRUNCATE TABLE bronze.crm_prd_info;
BULK INSERT bronze.crm_prd_info
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

-- Detail penjualan
TRUNCATE TABLE bronze.crm_sales_details;
BULK INSERT bronze.crm_sales_details
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

-- ===== ERP =====

-- Data pelanggan (tanggal lahir, gender)
TRUNCATE TABLE bronze.erp_cust_az12;
BULK INSERT bronze.erp_cust_az12
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

-- Lokasi pelanggan (negara)
TRUNCATE TABLE bronze.erp_loc_a101;
BULK INSERT bronze.erp_loc_a101
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

-- Kategori produk
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
BULK INSERT bronze.erp_px_cat_g1v2
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
