DECLARE @name VARCHAR(500)
DECLARE @cmd NVARCHAR(500)
DECLARE @Primary NVARCHAR(500)
DECLARE @Transactional NVARCHAR(500)

DECLARE restore_cursor CURSOR FOR  
Select rtrim(name) from sys.databases where name ='DB_1'

OPEN restore_cursor   
FETCH NEXT FROM restore_cursor INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN
	DECLARE @dbname sysname
	DECLARE @path  NVARCHAR(500)
	
	SET @path='E:\Backup\LDSNG_28Oct2012\' 
	SET @dbname = REPLACE (@name,'1','LDSIN')
		
    SET @Primary = (SELECT NAME FROM DB_1.dbo.sysfiles WHERE FILEID =1)
	SET @Transactional = (SELECT NAME FROM DB_1.dbo.sysfiles WHERE FILEID =2)
    SET @cmd = 'RESTORE DATABASE ['+@dbname+']
FROM DISK ='''+@path+@name+'.bak'' WITH FILE=1,
MOVE '''+@Primary+''' TO ''W:\MSSQL10_50.SQL1\MSSQL\Data\UserDB\'+@name+'.mdf'',
MOVE '''+@Transactional+''' TO ''W:\MSSQL10_50.SQL1\MSSQL\Data\UserDBLog\'+@name+'.ldf'',
NOUNLOAD,  STATS = 10, REPLACE
GO'
    PRINT @cmd
       
       FETCH NEXT FROM restore_cursor INTO @name   
END   

CLOSE restore_cursor   
DEALLOCATE restore_cursor