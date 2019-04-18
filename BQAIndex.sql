USE BQA
GO

DECLARE @Table VARCHAR(255)
DECLARE @Schema VARCHAR(255)
DECLARE @fillfactor INT 
DECLARE @cmd NVARCHAR(500)

SET @fillfactor = 90

DECLARE TableCursor CURSOR FOR 
SELECT DISTINCT(OBJECT_NAME(i.OBJECT_ID))
,SCHEMA_NAME(o.schema_id)
FROM sys.indexes i, sys.objects o,sys.dm_db_partition_stats st
WHERE o.type_desc='USER_TABLE'
AND i.index_id >0
AND o.object_id = i.object_id
AND o.object_id=st.object_id
AND o.modify_date < DATEADD(DD, -14, GETDATE())
AND st.row_count < 200001

OPEN TableCursor   

FETCH NEXT FROM TableCursor INTO @Table,@Schema
WHILE @@FETCH_STATUS = 0   
	BEGIN
	
	SET @cmd = 'ALTER INDEX ALL ON ' + @Schema+'.'+ @Table + ' REBUILD WITH (FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactor) + ')' 
        EXEC(@cmd) 
         
FETCH NEXT FROM TableCursor INTO @Table,@Schema 
END   

CLOSE TableCursor   
DEALLOCATE TableCursor