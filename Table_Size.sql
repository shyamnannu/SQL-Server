DBCC UPDATEUSAGE(0)
---------------------------------
CREATE TABLE #RowCountsAndSizes (TableName NVARCHAR(128),rows CHAR(11),      
       reserved VARCHAR(18),data VARCHAR(18),index_size VARCHAR(18), 
       unused VARCHAR(18))

EXEC       sp_MSforeachtable 'INSERT INTO #RowCountsAndSizes EXEC sp_spaceused ''?'' '

SELECT     TableName,CONVERT(bigint,rows) AS NumberOfRows,
            CONVERT(bigint,left(reserved,len(reserved)-3))/1024 AS TotalSizeinMB,
            CONVERT(bigint,left(Data,len(reserved)-3))/1024 AS DataSizeinMB,
            CONVERT(bigint,left(index_size,len(reserved)-3))/1024 AS index_sizeinMB,
            CONVERT(bigint,left(unused,len(reserved)-3))/1024 AS unusedSizeinMB
FROM       #RowCountsAndSizes 
ORDER BY   unusedSizeinMB DESC,index_sizeinMB DESC,TableName

DROP TABLE #RowCountsAndSizes
---------------------------------
USE DatabaseName

 

IF object_id('tempdb..#TableSize') IS NOT NULL

BEGIN

DROP TABLE #TableSize

END

 

create table #TableSize (name varchar(150), rows int, reserved varchar(150)

,data varchar(150), index_size varchar(150), unused varchar(150))

 

insert into #TableSize

EXEC sp_MSforeachtable @command1='EXEC sp_spaceused ''?'''

select name, cast(replace(data, ' KB','') as int)/1024 as TableDataSizeMB

from #TableSize

order by cast(replace(data, ' KB','') as int) desc

drop table #TableSize
