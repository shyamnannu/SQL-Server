USE master
GO

CREATE TABLE #Index_Information
(Table_Name varchar(100),Schema_Name varchar(100),Index_Name nvarchar(100),
Modify_Date Datetime,Database_name varchar(100))

declare @ssql nvarchar(4000)
set @ssql= '
        if ''?'' NOT in (''master'',''model'',''msdb'',''tempdb'') begin
        use [?]
        SELECT DISTINCT(OBJECT_NAME(i.OBJECT_ID))
,SCHEMA_NAME(o.schema_id),i.name,o.Modify_Date,DB_NAME()
FROM sys.indexes i, sys.objects o,sys.dm_db_partition_stats st
WHERE o.type_desc=''USER_TABLE''
AND i.index_id >0
AND o.object_id = i.object_id
AND o.object_id=st.object_id
AND o.modify_date > DATEADD(DD, -2, GETDATE())
end'

INSERT INTO #Index_Information exec sp_msforeachdb @ssql

SELECT * FROM #Index_Information

DROP TABLE #Index_Information