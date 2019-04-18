
DECLARE @name VARCHAR(500)
DECLARE @cmd NVARCHAR(500)


DECLARE owner_cursor CURSOR FOR  
Select name from sys.databases where database_id >6

OPEN owner_cursor   
FETCH NEXT FROM owner_cursor INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       SET @cmd = 'ALTER DATABASE ['+ @name + '] SET COMPATIBILITY_LEVEL = 100' 
       EXEC (@cmd)
       
       FETCH NEXT FROM owner_cursor INTO @name   
END   

CLOSE owner_cursor   
DEALLOCATE owner_cursor 