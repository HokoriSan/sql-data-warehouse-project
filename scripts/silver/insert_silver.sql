/* ============================================================
   SCRIPT   : Load silver.crm_cust_info  (SQL Server / T-SQL)
   SOURCE   : bronze.crm_cust_info
   TUJUAN   : Membersihkan dan menstandarkan data customer CRM
              sebelum masuk ke Silver Layer.

   IDEMPOTENSI:
     Script ini aman dijalankan berulang kali. Setiap eksekusi
     mengosongkan tabel silver lalu mengisinya ulang (full load)
     di dalam satu transaksi. Jika terjadi error, transaksi
     di-rollback sehingga data lama tetap utuh. Hasil akhir
     selalu sama, tanpa duplikasi.

   TRANSFORMASI:
     1. Deduplikasi: ambil record terbaru per cst_id berdasarkan
        cst_create_date (ROW_NUMBER, flag_last = 1).
     2. Membuang record dengan cst_id NULL.
     3. TRIM pada cst_firstname dan cst_lastname.
     4. Standarisasi cst_marital_status: M -> Married, S -> Single.
     5. Standarisasi cst_gndr: M -> Male, F -> Female.
     6. Nilai lain (NULL, kosong, kode baru) menjadi 'Unknown'.

   WARNING:
     1. Ini full load: seluruh isi tabel silver diganti setiap
        kali dijalankan. Tidak cocok untuk load inkremental.
     2. Selama transaksi berjalan, tabel silver terkunci. Query
        lain yang membaca tabel ini bisa menunggu.
     3. TRUNCATE gagal jika tabel direferensikan foreign key.
     4. Baris dengan cst_id NULL dibuang tanpa notifikasi. Pantau
        lewat query validasi.
     5. cst_key tidak di-TRIM; spasi tersembunyi dapat membuat
        join ke tabel lain gagal.
     6. TRIM() butuh SQL Server 2017+ dan hanya membuang spasi
        biasa, bukan tab/enter. Versi lama: LTRIM(RTRIM(kolom)).
     7. NULL pada ORDER BY DESC berada di urutan akhir di SQL
        Server, jadi cst_create_date NULL tidak akan terpilih.
     8. cst_key menjadi tie-breaker bila cst_id dan cst_create_date
        sama, agar hasil deterministik.
     9. SELECT * pada subquery rawan jika struktur bronze berubah.
        Sebutkan kolom secara eksplisit di versi produksi.
     10. Kode di luar M/S dan M/F menjadi 'Unknown'. Cek bronze
         secara berkala.
   ============================================================ */

SET XACT_ABORT ON;

BEGIN TRY
	BEGIN TRANSACTION;

	TRUNCATE TABLE silver.crm_cust_info;

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

	COMMIT TRANSACTION;
	PRINT 'Load silver.crm_cust_info berhasil.';
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	PRINT 'Load silver.crm_cust_info GAGAL. Transaksi di-rollback.';
	PRINT 'Error number  : ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
	PRINT 'Error message : ' + ERROR_MESSAGE();
	PRINT 'Error line    : ' + CAST(ERROR_LINE() AS VARCHAR(10));

	THROW;
END CATCH;

/* ============================================================
   VALIDASI SETELAH LOAD (jalankan terpisah)
   ============================================================

   -- 1. cst_id harus unik (hasil harus kosong)
   SELECT cst_id, COUNT(*) AS jumlah
   FROM silver.crm_cust_info
   GROUP BY cst_id
   HAVING COUNT(*) > 1;

   -- 2. Jumlah baris bronze yang dibuang karena cst_id NULL
   SELECT COUNT(*) AS baris_tanpa_id
   FROM bronze.crm_cust_info
   WHERE cst_id IS NULL;

   -- 3. Sebaran nilai 'Unknown'
   SELECT cst_marital_status, COUNT(*) AS jumlah
   FROM silver.crm_cust_info
   GROUP BY cst_marital_status;

   SELECT cst_gndr, COUNT(*) AS jumlah
   FROM silver.crm_cust_info
   GROUP BY cst_gndr;

   -- 4. Nilai asli di bronze yang menjadi 'Unknown'
   SELECT DISTINCT cst_marital_status, cst_gndr
   FROM bronze.crm_cust_info;
   ============================================================ */
