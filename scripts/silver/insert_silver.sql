/* ============================================================
   SCRIPT   : Load silver.crm_cust_info  (SQL Server / T-SQL)
   SOURCE   : bronze.crm_cust_info
   TUJUAN   : Membersihkan dan menstandarkan data customer CRM
              sebelum masuk ke Silver Layer.

   TRANSFORMASI:
     1. Deduplikasi: ambil record terbaru per cst_id berdasarkan
        cst_create_date (ROW_NUMBER, flag_last = 1).
     2. Membuang record dengan cst_id NULL (tidak bisa diidentifikasi).
     3. TRIM pada cst_firstname dan cst_lastname.
     4. Standarisasi cst_marital_status: M -> Married, S -> Single.
     5. Standarisasi cst_gndr: M -> Male, F -> Female.
     6. Nilai lain (NULL, kosong, kode baru) menjadi 'Unknown'.

   WARNING:
     1. Script dimulai dengan TRUNCATE sehingga seluruh isi tabel
        silver dihapus setiap kali dijalankan (full load).
     2. Baris dengan cst_id NULL dibuang tanpa notifikasi. Pantau
        jumlahnya lewat query validasi di bawah.
     3. cst_key tidak di-TRIM. Spasi tersembunyi di sumber dapat
        membuat join ke tabel lain gagal.
     4. TRIM() hanya membuang spasi biasa, bukan tab/enter
        (CHAR(9), CHAR(10), CHAR(13)). Perlu dicek jika bronze
        berasal dari file CSV.
     5. TRIM() membutuhkan SQL Server 2017+. Untuk versi lama
        gunakan LTRIM(RTRIM(kolom)).
     6. Di SQL Server, NULL pada ORDER BY DESC berada di urutan
        akhir, jadi record dengan cst_create_date NULL tidak akan
        terpilih sebagai yang terbaru.
     7. cst_key dipakai sebagai tie-breaker bila ada cst_id dan
        cst_create_date yang sama, supaya hasil deterministik.
     8. SELECT * pada subquery rawan jika struktur tabel bronze
        berubah. Sebutkan kolom secara eksplisit di versi produksi.
     9. Kode di luar M/S (marital status) dan M/F (gender) menjadi
        'Unknown'. Cek bronze secara berkala agar kode valid baru
        tidak terlewat.
   ============================================================ */

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
