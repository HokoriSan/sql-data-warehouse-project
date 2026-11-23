/*
===============================================================================
DDL Gold Layer
===============================================================================
Tujuan  : Membuat view Gold Layer (star schema) dari data Silver Layer.
Urutan  : dim_customers -> dim_products -> fact_sales

PERINGATAN UMUM:
- Surrogate key dibuat dengan ROW_NUMBER() di dalam view, jadi dihitung ulang
  setiap dibaca dan bisa bergeser jika ada data baru. Jangan dijadikan key
  permanen di luar view.
- Surrogate key pasti unik, jadi cek keunikan sebaiknya juga dilakukan pada
  customer_id dan product_number.
- Tiap CREATE VIEW harus berada di batch sendiri (dipisah GO).
===============================================================================
*/

/*
gold.dim_customers
- Sumber utama CRM, dilengkapi ERP (tanggal lahir dan negara).
- Gender: pakai CRM, jika 'Unkown' pakai ERP.
- PERINGATAN: ejaan 'Unkown' harus sama dengan Silver Layer. Jika cid di ERP
  ganda, satu pelanggan bisa muncul lebih dari satu baris.
*/
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cci.cst_id) AS customer_key,
    cci.cst_id AS customer_id,
    cci.cst_key AS customer_number,
    cci.cst_firstname AS first_name,
    cci.cst_lastname AS last_name,
    ela.cntry AS country,
    cci.cst_marital_status AS marital_status,
    CASE
        WHEN cci.cst_gndr != 'Unkown' THEN cci.cst_gndr
        ELSE COALESCE(eca.gen, 'Unkown')
    END AS gender,
    eca.bdate AS birth_date,
    cci.cst_create_date AS create_date
FROM silver.crm_cust_info cci
LEFT JOIN silver.erp_cust_az12 eca ON eca.cid = cci.cst_key
LEFT JOIN silver.erp_loc_a101 ela ON ela.cid = cci.cst_key;

/*
gold.dim_products
- Hanya produk aktif (prd_end_dt IS NULL), dilengkapi kategori dari ERP.
- PERINGATAN: riwayat produk tidak ikut. Penjualan untuk produk tanpa versi
  aktif akan mendapat product_key NULL di fact_sales.
*/
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cpi.prd_start_dt, cpi.prd_key) AS product_key,
    cpi.prd_id AS product_id,
    cpi.prd_key AS product_number,
    cpi.prd_cat_id AS category_id,
    cpi.prd_nm AS product_name,
    epcgv.cat AS category,
    epcgv.subcat AS sub_category,
    epcgv.maintenance,
    cpi.prd_cost AS cost,
    cpi.prd_line AS product_line,
    cpi.prd_start_dt AS start_date
FROM silver.crm_prd_info cpi
LEFT JOIN silver.erp_px_cat_g1v2 epcgv ON epcgv.id = cpi.prd_cat_id
WHERE cpi.prd_end_dt IS NULL;

/*
gold.fact_sales
- Mengganti id sumber dengan surrogate key dari kedua dimensi.
- PERINGATAN: LEFT JOIN membuat data tanpa pasangan tetap masuk dengan key
  NULL. Jika customer_id atau product_number di dimensi tidak unik, baris
  penjualan terduplikasi dan total sales_amount membengkak.
- Validasi dengan quality_checks_gold.sql setelah view dibuat.
*/
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;

CREATE VIEW gold.fact_sales AS
SELECT
    csd.sls_ord_num AS order_number,
    dp.product_key,
    dc.customer_key,
    csd.sls_order_dt AS order_date,
    csd.sls_ship_dt AS shipping_date,
    csd.sls_due_dt AS due_date,
    csd.sls_sales AS sales_amount,
    csd.sls_quantity AS quantity,
    csd.sls_price AS price
FROM silver.crm_sales_details csd
LEFT JOIN gold.dim_customers dc ON dc.customer_id = csd.sls_cust_id
LEFT JOIN gold.dim_products dp ON dp.product_number = csd.sls_prd_key;
