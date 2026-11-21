/*
===============================================================================
DDL Script: Membuat Tabel Layer Silver
===============================================================================
Tujuan:
    Script ini membuat tabel di schema 'silver'. Jika tabel sudah ada,
    tabel akan di-drop lalu dibuat ulang.

Catatan:
    - Pastikan schema 'silver' sudah dibuat sebelum menjalankan script ini
      (CREATE SCHEMA silver;).
    - Layer silver berisi data yang sudah dibersihkan dan distandarisasi
      dari layer bronze, sehingga tipe datanya mengikuti tipe yang benar
      (misalnya tanggal bertipe DATE, bukan INT).
    - Kolom dwh_create_date mencatat kapan baris dimuat ke data warehouse.
===============================================================================
*/

-- CRM: informasi pelanggan
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date     DATETIME2 DEFAULT GETDATE()
);
GO

-- CRM: informasi produk
-- prd_cat_id adalah hasil ekstrak dari prd_key (kode kategori),
-- digunakan untuk join ke silver.erp_px_cat_g1v2.id
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id           INT,
    prd_cat_id       NVARCHAR(50),
    prd_key          NVARCHAR(50),
    prd_nm           NVARCHAR(50),
    prd_cost         INT,
    prd_line         NVARCHAR(50),
    prd_start_dt     DATE,
    prd_end_dt       DATE,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- CRM: detail penjualan
-- Di layer bronze, kolom tanggal (sls_order_dt, sls_ship_dt, sls_due_dt)
-- berbentuk angka INT (misalnya 20240115). Di layer silver kolom tersebut
-- sudah dikonversi ke DATE. Nilai tidak valid (0 atau panjang bukan 8 digit)
-- diubah menjadi NULL pada proses load.
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num      NVARCHAR(50),
    sls_prd_key      NVARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE,
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_sales        INT,
    sls_quantity     INT,
    sls_price        INT,
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- ERP: data pelanggan (tanggal lahir, gender)
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid              NVARCHAR(50),
    bdate            DATE,
    gen              NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- ERP: lokasi pelanggan (negara)
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid              NVARCHAR(50),
    cntry            NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

-- ERP: kategori produk
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id               NVARCHAR(50),
    cat              NVARCHAR(50),
    subcat           NVARCHAR(50),
    maintenance      NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO
