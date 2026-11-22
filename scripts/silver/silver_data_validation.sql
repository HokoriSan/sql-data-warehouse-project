/* ============================================================
   VALIDASI SILVER LAYER
   Query bertanda "idealnya kosong" harus tidak mengembalikan
   baris. Query lain dibaca manual.
   ============================================================ */

/* ---------- 1. silver.crm_cust_info ---------- */

-- Jumlah baris (silver = bronze - duplikat - cst_id NULL)
SELECT
	(SELECT COUNT(*) FROM bronze.crm_cust_info) AS bronze_total,
	(SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL) AS bronze_id_null,
	(SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL) AS bronze_id_unik,
	(SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_total;   -- harus = bronze_id_unik

-- cst_id duplikat (idealnya kosong)
SELECT cst_id, COUNT(*) AS jumlah
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Sisa spasi/karakter tersembunyi (idealnya kosong)
SELECT cst_id, cst_key, cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE DATALENGTH(cst_key)       <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM cst_key))
   OR DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM cst_firstname))
   OR DATALENGTH(cst_lastname)  <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM cst_lastname));

-- Standarisasi: nilai di luar yang diizinkan (idealnya kosong)
SELECT cst_id, cst_marital_status, cst_gndr
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Married', 'Single', 'Unknown')
   OR cst_gndr NOT IN ('Male', 'Female', 'Unknown');

-- Sebaran nilai (jika 'Unknown' terlalu banyak, ada kode terlewat)
SELECT cst_marital_status, COUNT(*) AS jumlah FROM silver.crm_cust_info GROUP BY cst_marital_status;
SELECT cst_gndr, COUNT(*) AS jumlah FROM silver.crm_cust_info GROUP BY cst_gndr;

-- Nilai asli bronze untuk kode yang berubah jadi 'Unknown'
SELECT DISTINCT cst_marital_status, cst_gndr, CAST(cst_marital_status AS VARBINARY(20)) AS hex_ms
FROM bronze.crm_cust_info;

/* ---------- 2. silver.crm_prd_info ---------- */

-- Jumlah baris harus sama dengan bronze
SELECT
	(SELECT COUNT(*) FROM bronze.crm_prd_info) AS bronze_total,
	(SELECT COUNT(*) FROM silver.crm_prd_info) AS silver_total;

-- prd_id duplikat atau NULL (idealnya kosong)
SELECT prd_id, COUNT(*) AS jumlah
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Tanggal akhir lebih kecil dari tanggal mulai (idealnya kosong)
SELECT prd_id, prd_key, prd_start_dt, prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- Setiap prd_key harus punya tepat 1 versi aktif (end_dt NULL); hasil idealnya kosong
SELECT prd_key,
	SUM(CASE WHEN prd_end_dt IS NULL THEN 1 ELSE 0 END) AS jumlah_aktif
FROM silver.crm_prd_info
GROUP BY prd_key
HAVING SUM(CASE WHEN prd_end_dt IS NULL THEN 1 ELSE 0 END) <> 1;

-- Biaya NULL / negatif / nol (nol berasal dari ISNULL, cek apakah wajar)
SELECT prd_id, prd_key, prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost <= 0;

-- Standarisasi prd_line: nilai di luar yang diizinkan (idealnya kosong)
SELECT DISTINCT prd_line
FROM silver.crm_prd_info
WHERE prd_line NOT IN ('Road', 'Mountain', 'Other Sales', 'Touring', 'Unknown');

SELECT prd_line, COUNT(*) AS jumlah FROM silver.crm_prd_info GROUP BY prd_line;

-- Sisa spasi pada prd_nm dan prd_key (idealnya kosong)
SELECT prd_id, prd_nm, prd_key
FROM silver.crm_prd_info
WHERE DATALENGTH(prd_nm)  <> DATALENGTH(TRIM(prd_nm))
   OR DATALENGTH(prd_key) <> DATALENGTH(TRIM(prd_key));

-- prd_cat_id yang tidak ada di erp_px_cat_g1v2 (idealnya kosong/sedikit)
SELECT DISTINCT p.prd_cat_id
FROM silver.crm_prd_info p
WHERE NOT EXISTS (SELECT 1 FROM silver.erp_px_cat_g1v2 c WHERE c.id = p.prd_cat_id);

/* ---------- 3. silver.crm_sales_details ---------- */

-- Jumlah baris harus sama dengan bronze
SELECT
	(SELECT COUNT(*) FROM bronze.crm_sales_details) AS bronze_total,
	(SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_total;

-- Tanggal yang menjadi NULL (cek apakah wajar)
SELECT
	SUM(CASE WHEN sls_order_dt IS NULL THEN 1 ELSE 0 END) AS order_null,
	SUM(CASE WHEN sls_ship_dt  IS NULL THEN 1 ELSE 0 END) AS ship_null,
	SUM(CASE WHEN sls_due_dt   IS NULL THEN 1 ELSE 0 END) AS due_null
FROM silver.crm_sales_details;

-- Urutan tanggal tidak logis (idealnya kosong)
SELECT sls_ord_num, sls_order_dt, sls_ship_dt, sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Sales, quantity, price tidak konsisten (idealnya kosong)
SELECT sls_ord_num, sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;

-- Sisa spasi pada kunci (idealnya kosong)
SELECT sls_ord_num, sls_prd_key
FROM silver.crm_sales_details
WHERE DATALENGTH(sls_ord_num) <> DATALENGTH(TRIM(sls_ord_num))
   OR DATALENGTH(sls_prd_key) <> DATALENGTH(TRIM(sls_prd_key));

-- Relasi: produk yang tidak ada di crm_prd_info (idealnya kosong)
SELECT DISTINCT s.sls_prd_key
FROM silver.crm_sales_details s
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_key = s.sls_prd_key);

-- Relasi: customer yang tidak ada di crm_cust_info (idealnya kosong)
SELECT DISTINCT s.sls_cust_id
FROM silver.crm_sales_details s
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_id = s.sls_cust_id);

/* ---------- 4. silver.erp_cust_az12 ---------- */

-- Jumlah baris harus sama dengan bronze
SELECT
	(SELECT COUNT(*) FROM bronze.erp_cust_az12) AS bronze_total,
	(SELECT COUNT(*) FROM silver.erp_cust_az12) AS silver_total;

-- cid duplikat (idealnya kosong)
SELECT cid, COUNT(*) AS jumlah
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1;

-- Prefix NAS atau karakter tersembunyi masih tersisa di cid (idealnya kosong)
SELECT cid
FROM silver.erp_cust_az12
WHERE cid LIKE 'NAS%'
   OR DATALENGTH(cid) <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM cid));

-- Standarisasi gen (idealnya kosong)
SELECT DISTINCT gen FROM silver.erp_cust_az12 WHERE gen NOT IN ('Male', 'Female', 'Unknown');

SELECT gen, COUNT(*) AS jumlah FROM silver.erp_cust_az12 GROUP BY gen;

-- Tanggal lahir di luar batas (batas bawah 1924-01-01 hanya contoh; idealnya kosong)
SELECT cid, bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- Relasi: cid yang tidak cocok dengan cst_key (idealnya kosong/sedikit)
SELECT a.cid
FROM silver.erp_cust_az12 a
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key = a.cid);

/* ---------- 5. silver.erp_loc_a101 ---------- */

-- Jumlah baris harus sama dengan bronze
SELECT
	(SELECT COUNT(*) FROM bronze.erp_loc_a101) AS bronze_total,
	(SELECT COUNT(*) FROM silver.erp_loc_a101) AS silver_total;

-- cid duplikat (idealnya kosong)
SELECT cid, COUNT(*) AS jumlah
FROM silver.erp_loc_a101
GROUP BY cid
HAVING COUNT(*) > 1;

-- Tanda '-' atau karakter tersembunyi masih ada di cid (idealnya kosong)
SELECT cid
FROM silver.erp_loc_a101
WHERE cid LIKE '%-%'
   OR cid LIKE '%' + CHAR(13) + '%'
   OR cid LIKE '%' + CHAR(10) + '%'
   OR cid LIKE '%' + CHAR(160) + '%'
   OR cid LIKE '% %';

-- Standarisasi cntry: lihat semua nilai (cari kode singkat yang belum dipetakan)
SELECT cntry, COUNT(*) AS jumlah
FROM silver.erp_loc_a101
GROUP BY cntry
ORDER BY cntry;

-- Kode singkat 2-3 huruf yang belum dipetakan (idealnya kosong)
SELECT DISTINCT cntry
FROM silver.erp_loc_a101
WHERE LEN(cntry) <= 3 AND cntry <> 'Unknown';

-- Relasi: cid yang tidak cocok dengan cst_key (idealnya kosong/sedikit)
SELECT l.cid
FROM silver.erp_loc_a101 l
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_cust_info c WHERE c.cst_key = l.cid);

/* ---------- 6. silver.erp_px_cat_g1v2 ---------- */

-- Jumlah baris harus sama dengan bronze
SELECT
	(SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2) AS bronze_total,
	(SELECT COUNT(*) FROM silver.erp_px_cat_g1v2) AS silver_total;

-- id duplikat atau NULL (idealnya kosong)
SELECT id, COUNT(*) AS jumlah
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL;

-- Sisa spasi/karakter tersembunyi (idealnya kosong)
SELECT id, cat, subcat, maintenance
FROM silver.erp_px_cat_g1v2
WHERE DATALENGTH(id)          <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM id))
   OR DATALENGTH(cat)         <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM cat))
   OR DATALENGTH(subcat)      <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM subcat))
   OR DATALENGTH(maintenance) <> DATALENGTH(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM maintenance));

-- Standarisasi: lihat nilai distinct (harus konsisten, mis. hanya 'Yes' / 'No')
SELECT maintenance, COUNT(*) AS jumlah FROM silver.erp_px_cat_g1v2 GROUP BY maintenance;
SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2 ORDER BY cat;

-- Relasi: kategori yang tidak dipakai produk mana pun (informasi saja)
SELECT c.id
FROM silver.erp_px_cat_g1v2 c
WHERE NOT EXISTS (SELECT 1 FROM silver.crm_prd_info p WHERE p.prd_cat_id = c.id);
