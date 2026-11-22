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

-- INSERTING DATA INTO crm_prd_info TABLE
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
	cpi.prd_id ,
	REPLACE(SUBSTRING(cpi.prd_key , 1, 5), '-','_') AS prd_cat_id ,
	SUBSTRING(cpi.prd_key, 7, LEN(cpi.prd_key)) AS prd_key ,
	cpi.prd_nm ,
	ISNULL(cpi.prd_cost,0) AS prd_cost ,
	CASE UPPER(TRIM(cpi.prd_line))
		WHEN 'R' THEN 'Road'
		WHEN 'M' THEN 'Mountain'
		WHEN 'S' THEN 'Other Sales'
		WHEN 'T' THEN 'Touring'
		ELSE 'Unknown' END AS prid_line,
	CAST(cpi.prd_start_dt AS DATE) AS prd_start_dt,
	CAST(LEAD(cpi.prd_start_dt) OVER (PARTITION BY cpi.prd_key ORDER BY cpi.prd_start_dt ASC)-1 AS DATE) AS prd_end_dt 
FROM bronze.crm_prd_info cpi ;

SELECT *
FROM silver.crm_prd_info cpi
