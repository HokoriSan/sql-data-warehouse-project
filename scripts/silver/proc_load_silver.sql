/* ============================================================
   SCRIPT   : silver.load_silver  (SQL Server / T-SQL)
   TUJUAN   : Memuat data bronze -> silver (full load, 6 tabel).
   POLA     : Setiap tabel = TRUNCATE lalu INSERT, semuanya dalam
              satu transaksi. Jika ada error, semua di-rollback.
   CARA PAKAI: EXEC silver.load_silver;

   WARNING UMUM:
     1. Full load: isi tabel silver diganti total setiap eksekusi.
        Tidak cocok untuk load inkremental.
     2. Tabel silver terkunci selama transaksi berjalan.
     3. TRUNCATE gagal jika tabel direferensikan foreign key.
     4. TRIM(karakter FROM kolom) butuh SQL Server 2017+.
     5. Karakter pembersih: CHAR(9) tab, CHAR(10) line feed,
        CHAR(13) carriage return, CHAR(32) spasi,
        CHAR(160) non-breaking space.
     6. Urutan load tidak masalah untuk script ini, tetapi
        validasi relasi antar tabel hanya bermakna setelah
        semua tabel terisi.
   ============================================================ */

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @set_time DATETIME, @end_time DATETIME, @batch_set_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		BEGIN TRANSACTION;

		/* --------------------------------------------------------
		   TABEL 1: silver.crm_cust_info
		   SOURCE : bronze.crm_cust_info

		   TRANSFORMASI:
		     - Deduplikasi per cst_id, ambil cst_create_date terbaru.
		     - Buang cst_id NULL.
		     - TRIM pada cst_firstname dan cst_lastname.
		     - Marital status: M -> Married, S -> Single.
		     - Gender: M -> Male, F -> Female.
		     - Nilai lain (NULL, kosong, kode baru) -> 'Unknown'.

		   WARNING:
		     1. cst_id NULL dibuang tanpa notifikasi; pantau jumlahnya.
		     2. cst_key TIDAK di-TRIM. Spasi tersembunyi membuat join
		        ke erp_cust_az12 / erp_loc_a101 gagal diam-diam.
		     3. TRIM() biasa hanya membuang spasi biasa. Karakter
		        CHAR(13) dari file CSV pada marital status / gender
		        akan menjadi 'Unknown'.
		     4. SELECT * di subquery rawan jika struktur bronze berubah.
		     5. NULL pada ORDER BY DESC berada di akhir (SQL Server),
		        jadi tanggal NULL tidak akan terpilih sebagai terbaru.
		     6. cst_key hanya tie-breaker agar hasil konsisten.
		-------------------------------------------------------- */
		SET @batch_set_time = GETDATE();
		
		 PRINT '=======================================';
        PRINT 'Loading Silver Layer';
        PRINT '=======================================';

        PRINT '---------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '---------------------------------------';
        
		SET @set_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		
		 PRINT '>> Inserting Data Into : silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
		SELECT
			t.cst_id,
			t.cst_key,
			TRIM(t.cst_firstname) AS cst_firstname,
			TRIM(t.cst_lastname)  AS cst_lastname,
			CASE WHEN UPPER(TRIM(t.cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(t.cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'Unknown'
			END AS cst_marital_status,
			CASE WHEN UPPER(TRIM(t.cst_gndr)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(t.cst_gndr)) = 'F' THEN 'Female'
				ELSE 'Unknown'
			END AS cst_gndr,
			t.cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (
					PARTITION BY cci.cst_id
					ORDER BY cci.cst_create_date DESC, cci.cst_key
				) AS flag_last
			FROM bronze.crm_cust_info cci
			WHERE cci.cst_id IS NOT NULL
		) t
		WHERE t.flag_last = 1;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';

		/* --------------------------------------------------------
		   TABEL 2: silver.crm_prd_info
		   SOURCE : bronze.crm_prd_info

		   TRANSFORMASI:
		     - prd_cat_id : 5 karakter pertama prd_key, '-' -> '_'
		       (agar cocok dengan erp_px_cat_g1v2.id).
		     - prd_key    : karakter ke-7 dan seterusnya (kunci
		       produk murni, agar cocok dengan sls_prd_key).
		     - prd_cost   : NULL -> 0.
		     - prd_line   : R -> Road, M -> Mountain, S -> Other Sales,
		       T -> Touring, lainnya -> 'Unknown'.
		     - prd_end_dt : tanggal mulai versi berikutnya - 1 hari
		       per prd_key (LEAD). Versi terakhir bernilai NULL
		       (artinya masih berlaku).

		   WARNING:
		     1. prd_cost NULL menjadi 0. Nilai 0 bisa menurunkan rata-rata
		        biaya; bedakan "biaya nol" dan "biaya tidak diketahui".
		     2. LEAD(prd_start_dt) - 1 hanya valid jika prd_start_dt
		        bertipe DATETIME. Jika bertipe DATE akan error
		        "Operand type clash". Alternatif: DATEADD(DAY, -1, LEAD(...)).
		     3. LEAD memakai prd_key mentah (belum di-SUBSTRING); aman
		        selama format key di bronze konsisten.
		     4. prd_nm dan prd_key tidak di-TRIM; TRIM() biasa pada
		        prd_line tidak membuang CHAR(13).
		     5. Jika start_dt NULL atau dua versi punya start_dt sama,
		        end_dt bisa NULL atau lebih kecil dari start_dt.
		     6. Kode prd_line baru di bronze menjadi 'Unknown'.
		   -------------------------------------------------------- */
		SET @batch_set_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		
		PRINT '>> Inserting Data Into : silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			prd_cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			cpi.prd_id,
			REPLACE(SUBSTRING(cpi.prd_key, 1, 5), '-', '_') AS prd_cat_id,
			SUBSTRING(cpi.prd_key, 7, LEN(cpi.prd_key))     AS prd_key,
			cpi.prd_nm,
			ISNULL(cpi.prd_cost, 0) AS prd_cost,
			CASE UPPER(TRIM(cpi.prd_line))
				WHEN 'R' THEN 'Road'
				WHEN 'M' THEN 'Mountain'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'T' THEN 'Touring'
				ELSE 'Unknown'
			END AS prd_line,
			CAST(cpi.prd_start_dt AS DATE) AS prd_start_dt,
			CAST(LEAD(cpi.prd_start_dt) OVER (
				PARTITION BY cpi.prd_key
				ORDER BY cpi.prd_start_dt ASC
			) - 1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info cpi;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';
		
		/* --------------------------------------------------------
		   TABEL 3: silver.crm_sales_details
		   SOURCE : bronze.crm_sales_details

		   TRANSFORMASI:
		     - Tanggal (int yyyymmdd) -> DATE. Nilai 0, bukan 8 digit,
		       atau tanggal tidak valid -> NULL.
		     - sls_sales dihitung ulang (quantity * price) jika NULL,
		       <= 0, atau tidak sama dengan quantity * price,
		       hanya bila sls_price > 0.
		     - sls_price dihitung ulang (sales / quantity) jika NULL
		       atau <= 0.
		     - TRIM pada sls_ord_num dan sls_prd_key.

		   WARNING:
		     1. Jika sales dan price sama-sama rusak, hasilnya bisa NULL.
		     2. Harga negatif tidak dibalik tandanya (tanpa ABS);
		        ini keputusan aturan bisnis.
		     3. sls_sales dan sls_price di tabel silver sebaiknya
		        DECIMAL agar tidak dibulatkan.
		     4. Urutan tanggal (order <= ship <= due) belum divalidasi
		        di sini.
		     5. sls_prd_key harus cocok dengan crm_prd_info.prd_key
		        (hasil SUBSTRING), dan sls_cust_id dengan
		        crm_cust_info.cst_id; cek lewat validasi relasi.
		   -------------------------------------------------------- */
		SET @set_time = GETDATE();
		PRINT '>> Truncating Table : silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		
		PRINT '>> Inserting Data Into : silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT
			TRIM(csd.sls_ord_num) AS sls_ord_num,
			TRIM(csd.sls_prd_key) AS sls_prd_key,
			csd.sls_cust_id,
			CASE WHEN csd.sls_order_dt = 0 OR LEN(csd.sls_order_dt) != 8 THEN NULL
				ELSE TRY_CAST(CAST(csd.sls_order_dt AS VARCHAR(8)) AS DATE)
			END AS sls_order_dt,
			CASE WHEN csd.sls_ship_dt = 0 OR LEN(csd.sls_ship_dt) != 8 THEN NULL
				ELSE TRY_CAST(CAST(csd.sls_ship_dt AS VARCHAR(8)) AS DATE)
			END AS sls_ship_dt,
			CASE WHEN csd.sls_due_dt = 0 OR LEN(csd.sls_due_dt) != 8 THEN NULL
				ELSE TRY_CAST(CAST(csd.sls_due_dt AS VARCHAR(8)) AS DATE)
			END AS sls_due_dt,
			CASE WHEN csd.sls_price > 0
					AND (csd.sls_sales IS NULL
						OR csd.sls_sales <= 0
						OR csd.sls_sales != csd.sls_quantity * csd.sls_price)
				THEN csd.sls_quantity * csd.sls_price
				ELSE csd.sls_sales
			END AS sls_sales,
			csd.sls_quantity,
			CASE WHEN csd.sls_price IS NULL OR csd.sls_price <= 0
				THEN CAST(csd.sls_sales AS DECIMAL(18, 2)) / NULLIF(csd.sls_quantity, 0)
				ELSE csd.sls_price
			END AS sls_price
		FROM bronze.crm_sales_details csd;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';
		
		/* --------------------------------------------------------
		   TABEL 4: silver.erp_cust_az12
		   SOURCE : bronze.erp_cust_az12

		   TRANSFORMASI:
		     - cid : prefix 'NAS' dibuang agar cocok dengan cst_key.
		     - bdate : tanggal di masa depan -> NULL.
		     - gen : F/FEMALE -> Female, M/MALE -> Male,
		       lainnya -> 'Unknown'.

		   WARNING:
		     1. cid TIDAK dibersihkan sebelum dicek LIKE 'NAS%'. Spasi
		        atau karakter tersembunyi di depan membuat prefix tidak
		        terbuang dan join ke cst_key gagal diam-diam.
		     2. bdate hanya dicek batas atas. Tanggal mustahil di masa
		        lalu (mis. tahun 1900) lolos; tentukan batas bawah.
		     3. Duplikat cid belum ditangani.
		     4. Kode gender lain (mis. bahasa lokal) menjadi 'Unknown'.
		   -------------------------------------------------------- */
		PRINT '---------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '---------------------------------------';
		
		SET @end_time = GETDATE();		
		PRINT '>> Truncating Table : silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;

		PRINT '>> Inserting Data Into : silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE WHEN eca.cid LIKE 'NAS%' THEN SUBSTRING(eca.cid, 4, LEN(eca.cid))
				ELSE eca.cid
			END AS cid,
			CASE WHEN eca.bdate > GETDATE() THEN NULL
				ELSE eca.bdate
			END AS bdate,
			CASE WHEN UPPER(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM eca.gen)) IN ('F', 'FEMALE') THEN 'Female'
				WHEN UPPER(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM eca.gen)) IN ('M', 'MALE') THEN 'Male'
				ELSE 'Unknown'
			END AS gen
		FROM bronze.erp_cust_az12 eca;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';
		
		/* --------------------------------------------------------
		   TABEL 5: silver.erp_loc_a101
		   SOURCE : bronze.erp_loc_a101

		   TRANSFORMASI:
		     - cid : tanda '-' dibuang agar cocok dengan cst_key.
		     - cntry : NULL/kosong -> 'Unknown'; DE -> Germany;
		       US/USA -> United States; kode lain dibiarkan.

		   WARNING:
		     1. cid hanya membuang '-' biasa; spasi, CHAR(13), atau
		        en dash tidak ikut terbuang.
		     2. Kode negara lain (AU, FR, UK, dll.) belum dipetakan.
		     3. Ekspresi TRIM ditulis berulang; jika daftar karakter
		        berubah, ubah di semua tempat.
		     4. Duplikat cid belum ditangani.
		   -------------------------------------------------------- */
		
		SET @end_time = GETDATE();
		PRINT '>> Truncating Table : silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;

		PRINT '>> Inserting Data Into : silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(ela.cid, '-', '') AS cid,
			CASE WHEN TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM ela.cntry) IS NULL
					OR TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM ela.cntry) = ''
				THEN 'Unknown'
				WHEN UPPER(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM ela.cntry)) = 'DE'
				THEN 'Germany'
				WHEN UPPER(TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM ela.cntry)) IN ('USA', 'US')
				THEN 'United States'
				ELSE TRIM(CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32) + CHAR(160) FROM ela.cntry)
			END AS cntry
		FROM bronze.erp_loc_a101 ela;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';
		
		/* --------------------------------------------------------
		   TABEL 6: silver.erp_px_cat_g1v2
		   SOURCE : bronze.erp_px_cat_g1v2

		   TRANSFORMASI:
		     - Tidak ada (salin langsung, kolom per kolom).

		   WARNING:
		     1. Tidak ada pembersihan sama sekali. Spasi atau CHAR(13)
		        (kolom terakhir, maintenance, paling rawan dari CSV)
		        ikut masuk ke silver.
		     2. id harus cocok dengan crm_prd_info.prd_cat_id
		        (format dengan underscore, mis. AC_BR).
		     3. Duplikat id belum ditangani.
		   -------------------------------------------------------- */
		SET @end_time = GETDATE();		
		PRINT '>> Truncating Table : silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;

		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			epcgv.id,
			epcgv.cat,
			epcgv.subcat,
			epcgv.maintenance
		FROM bronze.erp_px_cat_g1v2 epcgv;

		SET @end_time = GETDATE();
		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @set_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------------------';
			
		COMMIT TRANSACTION;
		SET @batch_end_time = GETDATE();
		PRINT '=======================================';
		PRINT '  - Total Load Duration : ' + CAST(DATEDIFF(second, @batch_set_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		 PRINT '=======================================';
	
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;
		PRINT '=======================================';
		PRINT '>> ERROR OCCURRED DURING LOADING SILVER LAYER';
		PRINT 'Error message : ' + ERROR_MESSAGE();
		PRINT 'Error number  : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error state    : ' + CAST(ERROR_STATE() AS NVARCHAR);
		 PRINT '=======================================';
		THROW;
	END CATCH;
END;

EXEC silver.load_silver;
