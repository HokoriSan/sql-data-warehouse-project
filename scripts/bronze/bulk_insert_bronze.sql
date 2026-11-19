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
GO

BULK INSERT bronze.crm_prd_info
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	TABLOCK
);
GO

BULK INSERT bronze.crm_sales_details
FROM 'D:\Developer\SQL\Data With Baraa\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',' ,
	TABLOCK
);
GO
