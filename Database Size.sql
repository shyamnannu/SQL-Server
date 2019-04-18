USE [VIT_GLOBAL_TOOLBOX]
GO

CREATE TABLE DatabaseSize
(Database_Name sysname,
Filetype varchar(100),
FileSizeMB nvarchar(255),
SpaceUsedMB nvarchar(255),
FreeSpaceMB nvarchar (255)
)

DECLARE @name VARCHAR(500)
DECLARE @cmd NVARCHAR(500)

DECLARE owner_cursor CURSOR FOR  
Select name from sys.databases where name like '%ConfigDB' or name like  '%admincontentDB' order by name

OPEN owner_cursor   
FETCH NEXT FROM owner_cursor INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN   
SET @cmd = '
use ['+@name+']
go

INSERT INTO VIT_GLOBAL_TOOLBOX.dbo.DatabaseSize
select
db_name(),
''filetype''=
CASE fileid
WHEN ''1'' THEN ''DATA''
WHEN ''2'' THEN ''LOG''
END
, convert(decimal(12,2),round(a.size/128.000,2)) as FileSizeMB
, convert(decimal(12,2),round(fileproperty(a.name,''SpaceUsed'')/128.000,2)) as SpaceUsedMB
, convert(decimal(12,2),round((a.size-fileproperty(a.name,''SpaceUsed''))/128.000,2)) as FreeSpaceMB
from dbo.sysfiles a
GO
' 
       PRINT (@cmd)
       
       FETCH NEXT FROM owner_cursor INTO @name   
END   

CLOSE owner_cursor   
DEALLOCATE owner_cursor

SELECT * FROM VIT_GLOBAL_TOOLBOX.dbo.DatabaseSize

DROP TABLE VIT_GLOBAL_TOOLBOX.dbo.DatabaseSize



