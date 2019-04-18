
DECLARE @name VARCHAR(500)
DECLARE @cmd NVARCHAR(500)
DECLARE @login NVARCHAR(100)

DECLARE owner_cursor CURSOR FOR  
Select name from sys.databases where create_date > '2011-10-03'  

OPEN owner_cursor   
FETCH NEXT FROM owner_cursor INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN   
       SET @login = 'VCN\cs-ws-s-EPM2010'
       SET @cmd = 'EXEC ['+ @name + '].dbo.sp_changedbowner [' +@login+ ']' 
       EXEC (@cmd)
       
       FETCH NEXT FROM owner_cursor INTO @name   
END   

CLOSE owner_cursor   
DEALLOCATE owner_cursor 

-------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @RC int
DECLARE @login_name sysname
DECLARE @user NVARCHAR(100)
DECLARE @cmd NVARCHAR(500)


DECLARE login_cursor CURSOR FOR  
select RTRIM(name) from sysusers where name NOT IN ('dbo','public','guest','sys','db_owner','db_accessadmin','db_securityadmin','db_ddladmin','db_backupoperator',
'db_datareader','db_datawriter','db_denydatareader','db_denydatawriter','INFORMATION_SCHEMA') 

OPEN login_cursor   
FETCH NEXT FROM login_cursor INTO @user  

WHILE @@FETCH_STATUS = 0   
BEGIN   
       SET @cmd = 'EXECUTE master.dbo.sp_help_revlogin @login_name=''' + @user+''''
       EXEC (@cmd)
       
       FETCH NEXT FROM login_cursor INTO @user  
END   

CLOSE login_cursor   
DEALLOCATE login_cursor 

-------------------------------------------------------------------------------------------------------------------------------------------