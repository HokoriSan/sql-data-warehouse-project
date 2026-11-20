--INSERT CSV INTO OUR DATABASE
BULK INSERT bronze.crm_cust_info
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

BULK INSERT bronze.crm_prd_info
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

BULK INSERT bronze.crm_sales_details
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

BULK INSERT bronze.erp_cust_az12 
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

BULK INSERT bronze.erp_loc_a101 
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);

BULK INSERT bronze.erp_px_cat_g1v2 
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	ROWTERMINATOR = '0x0a',
	CODEPAGE = '65001',
	TABLOCK
);
