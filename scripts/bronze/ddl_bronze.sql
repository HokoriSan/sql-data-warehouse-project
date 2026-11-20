/*
===============================================================================
DDL Script: Membuat Tabel Layer Bronze
===============================================================================
Tujuan:
    Membuat tabel di schema 'bronze' untuk menampung data mentah dari
    sistem sumber (CRM dan ERP). Jika tabel sudah ada, tabel akan di-drop
    lalu dibuat ulang.

CATATAN:
    - Layer bronze = data mentah apa adanya dari sumber, tanpa transformasi.
    - Sengaja TIDAK ada PRIMARY KEY, FOREIGN KEY, atau constraint lain,
      supaya proses load tidak gagal karena data kotor.
    - Karena itu duplikat, NULL, dan format tidak konsisten BOLEH muncul.
      Pembersihan dilakukan di layer silver, bukan di sini.
    - Tipe data mengikuti bentuk data di file sumber, termasuk kolom tanggal
      yang masih berupa INT (lihat catatan di crm_sales_details).
    - Schema 'bronze' harus sudah dibuat sebelum script ini dijalankan.

PERINGATAN:
    - Script ini menjalankan DROP TABLE. SEMUA DATA di tabel bronze akan
      HILANG setiap script dijalankan. Jangan dijalankan di database produksi.
    - Setelah script ini dijalankan, tabel kosong. Data harus di-load ulang
      (misalnya dengan BULK INSERT).
===============================================================================
*/

-- CRM: informasi pelanggan
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;  -- jika sudah ada, drop lalu buat ulang
CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO

-- CRM: informasi produk
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
    prd_id        INT,
    prd_key       NVARCHAR(50),
    prd_nm        NVARCHAR(50),
    prd_cost      INT,
    prd_line      NVARCHAR(50),
    prd_start_dt  DATETIME,
    prd_end_dt    DATETIME
);
GO

-- CRM: detail penjualan
-- CATATAN: kolom tanggal (sls_order_dt, sls_ship_dt, sls_due_dt) bertipe INT
-- karena di sumber berbentuk angka (misal 20240115). Konversi ke DATE
-- dilakukan di layer silver, dan nilai tidak valid (0 atau panjang tidak
-- sesuai) harus ditangani di sana.
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num   NVARCHAR(50),
    sls_prd_key   NVARCHAR(50),
    sls_cust_id   INT,
    sls_order_dt  INT,
    sls_ship_dt   INT,
    sls_due_dt    INT,
    sls_sales     INT,
    sls_quantity  INT,
    sls_price     INT
);
GO

-- ERP: data pelanggan (tanggal lahir, gender)
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
CREATE TABLE bronze.erp_cust_az12 (
    cid    NVARCHAR(50),
    bdate  DATE,
    gen    NVARCHAR(50)
);
GO

-- ERP: lokasi pelanggan (negara)
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
CREATE TABLE bronze.erp_loc_a101 (
    cid    NVARCHAR(50),
    cntry  NVARCHAR(50)
);
GO

-- ERP: kategori produk
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50)
);
GO
