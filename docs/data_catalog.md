# Katalog Data Gold Layer

## Ringkasan
Gold Layer adalah representasi data tingkat bisnis (*business-level*) yang disusun untuk mendukung kebutuhan analitik dan pelaporan. Layer ini terdiri dari **tabel dimensi** (*dimension tables*) dan **tabel fakta** (*fact tables*) untuk metrik bisnis tertentu.

| Tabel | Jenis | Deskripsi Singkat |
|-------|-------|-------------------|
| `gold.dim_customers` | Dimensi | Data pelanggan beserta informasi demografis dan geografis |
| `gold.dim_products` | Dimensi | Data produk beserta atribut-atributnya |
| `gold.fact_sales` | Fakta | Data transaksi penjualan |

---

## 1. `gold.dim_customers`

- **Tujuan:** Menyimpan detail pelanggan yang diperkaya dengan data demografis dan geografis.
- **Kolom:**

| Nama Kolom | Tipe Data | Deskripsi |
|------------|-----------|-----------|
| `customer_key` | INT | *Surrogate key* yang mengidentifikasi setiap record pelanggan secara unik di tabel dimensi. |
| `customer_id` | INT | Pengenal numerik unik yang diberikan kepada setiap pelanggan. |
| `customer_number` | NVARCHAR(50) | Pengenal alfanumerik pelanggan, digunakan untuk pelacakan dan referensi. |
| `first_name` | NVARCHAR(50) | Nama depan pelanggan sebagaimana tercatat di sistem. |
| `last_name` | NVARCHAR(50) | Nama belakang atau nama keluarga pelanggan. |
| `country` | NVARCHAR(50) | Negara tempat tinggal pelanggan (contoh: `'Australia'`). |
| `marital_status` | NVARCHAR(50) | Status pernikahan pelanggan (contoh: `'Married'`, `'Single'`). |
| `gender` | NVARCHAR(50) | Jenis kelamin pelanggan (contoh: `'Male'`, `'Female'`, `'Unknown'`). |
| `birthdate` | DATE | Tanggal lahir pelanggan dengan format YYYY-MM-DD (contoh: `1971-10-06`). |
| `create_date` | DATE | Tanggal record pelanggan dibuat di sistem. |

---

## 2. `gold.dim_products`

- **Tujuan:** Menyediakan informasi tentang produk beserta atribut-atributnya.
- **Kolom:**

| Nama Kolom | Tipe Data | Deskripsi |
|------------|-----------|-----------|
| `product_key` | INT | *Surrogate key* yang mengidentifikasi setiap record produk secara unik di tabel dimensi produk. |
| `product_id` | INT | Pengenal unik produk untuk keperluan pelacakan dan referensi internal. |
| `product_number` | NVARCHAR(50) | Kode alfanumerik terstruktur yang merepresentasikan produk, sering digunakan untuk kategorisasi atau inventaris. |
| `product_name` | NVARCHAR(50) | Nama deskriptif produk, mencakup detail penting seperti tipe, warna, dan ukuran. |
| `category_id` | NVARCHAR(50) | Pengenal unik kategori produk, yang menghubungkannya ke klasifikasi tingkat atas. |
| `category` | NVARCHAR(50) | Klasifikasi umum produk (contoh: `Bikes`, `Components`) untuk mengelompokkan item yang berkaitan. |
| `subcategory` | NVARCHAR(50) | Klasifikasi produk yang lebih rinci di dalam kategori, seperti jenis produk. |
| `maintenance` | NVARCHAR(50) | Menunjukkan apakah produk memerlukan perawatan (contoh: `'Yes'`, `'No'`). |
| `cost` | INT | Biaya atau harga dasar produk, dalam satuan mata uang. |
| `product_line` | NVARCHAR(50) | Lini atau seri produk tempat produk berada (contoh: `Road`, `Mountain`). |
| `start_date` | DATE | Tanggal produk mulai tersedia untuk dijual atau digunakan. |

---

## 3. `gold.fact_sales`

- **Tujuan:** Menyimpan data transaksi penjualan untuk kebutuhan analitik.
- **Kolom:**

| Nama Kolom | Tipe Data | Deskripsi |
|------------|-----------|-----------|
| `order_number` | NVARCHAR(50) | Pengenal alfanumerik unik untuk setiap pesanan penjualan (contoh: `'SO54496'`). |
| `product_key` | INT | *Surrogate key* yang menghubungkan pesanan ke tabel dimensi produk. |
| `customer_key` | INT | *Surrogate key* yang menghubungkan pesanan ke tabel dimensi pelanggan. |
| `order_date` | DATE | Tanggal pesanan dibuat. |
| `shipping_date` | DATE | Tanggal pesanan dikirim ke pelanggan. |
| `due_date` | DATE | Tanggal jatuh tempo pembayaran pesanan. |
| `sales_amount` | INT | Total nilai penjualan untuk *line item*, dalam satuan mata uang utuh (contoh: `25`). |
| `quantity` | INT | Jumlah unit produk yang dipesan pada *line item* (contoh: `1`). |
| `price` | INT | Harga per unit produk pada *line item*, dalam satuan mata uang utuh (contoh: `25`). |

---

## Relasi Antar Tabel

Gold Layer menggunakan model **star schema**: satu tabel fakta di tengah yang terhubung ke dua tabel dimensi melalui *surrogate key*.

| Tabel Fakta | Kolom | Tabel Dimensi | Kolom |
|-------------|-------|---------------|-------|
| `gold.fact_sales` | `customer_key` | `gold.dim_customers` | `customer_key` |
| `gold.fact_sales` | `product_key` | `gold.dim_products` | `product_key` |

Contoh query untuk menggabungkan ketiga tabel:

```sql
SELECT
    c.country,
    p.category,
    SUM(f.sales_amount) AS total_penjualan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_products  p ON f.product_key  = p.product_key
GROUP BY c.country, p.category;
```
