BEGIN
SET NOCOUNT ON
DECLARE
@db_name SYSNAME,
@tab_name SYSNAME,
@ind_name VARCHAR(500),
@schema_name SYSNAME,
@frag FLOAT,
@pages INT,
@min_id INT,
@max_id INT,
@stats_date VARCHAR(8)

--------------------------------------------------------------------------------------------------------------------------------------
--inserting the Fragmentation details
--------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #tempfrag
(
id INT IDENTITY,
table_name SYSNAME,
index_name VARCHAR(500),
frag FLOAT,
pages INT,
schemaName SYSNAME,
statsDate VARCHAR(8)
)			

DECLARE DB_cursor CURSOR FOR  
Select name from sys.databases where database_id >4

OPEN DB_cursor   
FETCH NEXT FROM DB_cursor INTO @db_name   

WHILE @@FETCH_STATUS = 0   
BEGIN
			
EXEC ('USE ['+@db_name+'];
INSERT INTO #tempfrag (table_name,index_name,frag,pages,schemaName,statsDate)
SELECT OBJECT_NAME(F.OBJECT_ID) obj,i.name ind,
f.avg_fragmentation_in_percent,
f.page_count,OBJECT_SCHEMA_NAME(f.object_id),
CONVERT(VARCHAR(8),STATS_DATE(I.OBJECT_ID,I.index_id),112)as statsdate
FROM SYS.DM_DB_INDEX_PHYSICAL_STATS (DB_ID(),NULL,NULL,NULL,NULL) F
JOIN SYS.INDEXES I
ON(F.OBJECT_ID=I.OBJECT_ID)AND i.index_id=f.index_id
JOIN INFORMATION_SCHEMA.TABLES S
ON (s.table_name=OBJECT_NAME(F.OBJECT_ID))
AND f.database_id=DB_ID()
AND OBJECTPROPERTY(I.OBJECT_ID,''ISSYSTEMTABLE'')=0
AND is_disabled = 0
'

)
SELECT @min_id=MIN(ID)FROM #tempfrag
SELECT @max_id=MAX(ID)FROM #tempfrag


--SELECT * FROM #tempfrag

WHILE (@min_id<=@max_id)
/*While loop begin*/
BEGIN
SELECT
@tab_name=table_name,
@schema_name=schemaname,
@ind_name=index_name ,
@frag=frag ,
@pages=pages,
@stats_date=statsDate
FROM #tempfrag WHERE id = @min_id

--------------------------------------------------------------------------------------------------------------------------------------
--Check the fragmentation greater than 30% and pages greater than 1000 then rebuild
--------------------------------------------------------------------------------------------------------------------------------------
IF (@ind_name IS NOT NULL)
/*First if condition*/
BEGIN
IF (@frag>80 AND @pages>1000)
/*Sub if condition 1st */
BEGIN
EXEC('USE ['+@db_name+'];ALTER INDEX ['+@ind_name+'] ON ['+@schema_name+'].['+@tab_name +'] REBUILD ')

END
--------------------------------------------------------------------------------------------------------------------------------------
--Check the fragmentation between 5% to 30% and pages greater than 1000 then reorganize
--------------------------------------------------------------------------------------------------------------------------------------
ELSE IF((@frag BETWEEN 50 AND 80) AND @pages>1000  )
/*Sub if condition 2nd */
BEGIN
BEGIN TRY
EXEC('USE ['+@db_name+'];ALTER INDEX ['+@ind_name+'] ON ['+@schema_name+'].['+@tab_name +'] REORGANIZE ')
IF (@stats_date <CONVERT(VARCHAR(8),DATEADD(HH,1,GETDATE()-10),112))
BEGIN
EXEC('USE ['+@db_name+'];UPDATE STATISTICS ['+@schema_name+'].['+@tab_name+'] (['+@ind_name+']) ' )
END
END TRY
BEGIN CATCH
--------------------------------------------------------------------------------------------------------------------------------------
--Check the fragmentation between 15% to 29% and pages greater than 1000 and page level
--lock disabled then rebuild
--------------------------------------------------------------------------------------------------------------------------------------
IF ERROR_NUMBER()=2552
EXEC('USE ['+@db_name+'];ALTER INDEX ['+@ind_name+'] ON ['+@schema_name+'].['+@tab_name +'] REBUILD ')
END CATCH
END

--------------------------------------------------------------------------------------------------------------------------------------
--Update the statistics  for all indexes if the first three conditions is false
--------------------------------------------------------------------------------------------------------------------------------------
/*Sub if condition 3rd*/
ELSE
BEGIN
IF (@stats_date < CONVERT(VARCHAR(8),DATEADD(HH,1,GETDATE()-10),112))
BEGIN
EXEC('USE ['+@db_name+'];UPDATE STATISTICS ['+@schema_name+'].['+@tab_name+'] (['+@ind_name+']) '  )
END
END
END
ELSE

BEGIN
IF (@stats_date < CONVERT(VARCHAR(8),DATEADD(HH,1,GETDATE()-10),112))
BEGIN
--------------------------------------------------------------------------------------------------------------------------------------
--Update the statistics  for all tables if the first three conditions is false
--------------------------------------------------------------------------------------------------------------------------------------
EXEC('USE ['+@db_name+'];UPDATE STATISTICS ['+@schema_name+'].['+@tab_name+']')

END
/*End of the first if condition*/
END

SET @min_id=@min_id+1
/*While loop end*/
END

TRUNCATE TABLE #tempfrag

FETCH NEXT FROM DB_cursor INTO @db_name   
END   

CLOSE DB_cursor   
DEALLOCATE DB_cursor 

DROP TABLE #tempfrag

END
GO




