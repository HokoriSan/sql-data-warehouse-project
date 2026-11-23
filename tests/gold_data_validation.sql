/*
===============================================================================
Validasi Kualitas Data Gold Layer
===============================================================================
Tujuan:
    Script ini menjalankan pengecekan kualitas data untuk memastikan
    integritas, konsistensi, dan akurasi Gold Layer, meliputi:
    - Keunikan surrogate key pada tabel dimensi.
    - Konektivitas model data antara tabel fakta dan tabel dimensi.

Catatan Penggunaan:
    - Jalankan setelah proses load data ke Gold Layer selesai.
    - Hasil yang diharapkan: tidak ada baris yang dikembalikan (kosong).
===============================================================================
*/

-- ====================================================================
-- Pengecekan 'gold.dim_customers'
-- ====================================================================
-- Cek keunikan customer_key di gold.dim_customers
-- Ekspektasi: Tidak ada hasil
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Pengecekan 'gold.dim_products'
-- ====================================================================
-- Cek keunikan product_key di gold.dim_products
-- Ekspektasi: Tidak ada hasil
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Pengecekan 'gold.fact_sales'
-- ====================================================================
-- Cek konektivitas model data antara fakta dan dimensi
-- (mencari data penjualan yang tidak punya pasangan di dimensi)
-- Ekspektasi: Tidak ada hasil
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL
   OR c.customer_key IS NULL;
