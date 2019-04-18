SET NOCOUNT ON

CREATE TABLE #Permission
(database_name [nvarchar](100) NOT NULL,
UserName [nvarchar](100) NOT NULL,
RoleName [nvarchar](100) NOT NULL,
) 

DECLARE @ssql nvarchar(4000)
SET @ssql= '
        IF ''?'' LIKE ''TP_TeamplaceWebApp_ContentDB_%''
		BEGIN
        USE [?]
        SELECT DB_NAME(),USER_NAME(member_principal_id),USER_NAME(role_principal_id) from sys.database_role_members
		WHERE  USER_NAME(member_principal_id) LIKE ''%vcn\cs-ws-s-tp-tp-wa%''
        END'
        
INSERT INTO #Permission EXEC master..sp_msforeachdb @ssql

SELECT * FROM #Permission

DROP TABLE #Permission

-------------------------------------------------------------------------------------------------------------------------------------------
DECLARE @dbname sysname

DECLARE Permission_cursor CURSOR FOR  
select RTRIM(name) from sys.databases where name like 'LDSIN_%' 

OPEN Permission_cursor   
FETCH NEXT FROM Permission_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0   
BEGIN   
       DECLARE @user_name NVARCHAR(100)
       SET @user_name ='ldsindia'
       
       PRINT 'USE ['+@dbname+']'
       PRINT 'GO'
       PRINT 'CREATE USER ['+@user_name+'] FOR LOGIN ['+@user_name+']'
       PRINT 'EXEC sp_addrolemember ''dbowner'','''+@user_name+''''
       PRINT 'GO'
       
       FETCH NEXT FROM Permission_cursor INTO @dbname  
END   

CLOSE Permission_cursor   
DEALLOCATE Permission_cursor 
-------------------------------------------------------------------------------------------------------------------------------------------

DECLARE @ssql nvarchar(4000)
SET @ssql= '
        IF ''?'' LIKE ''LDSIN_%''
		BEGIN
        USE [?]
        CREATE USER [ldsindia] FOR LOGIN [ldsindia]
        EXEC sp_addrolemember ''db_owner'',''ldsindia''
        END'

EXEC master..sp_MSforeachdb @ssql
-------------------------------------------------------------------------------------------------------------------------------------------