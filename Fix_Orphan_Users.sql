/* To checl Orphan SQL logins and Fix them */

declare @ssql nvarchar(4000)
set @ssql= '
        if ''?'' NOT in (''master'',''model'',''msdb'',''tempdb'') begin
        use [?]
        
--Create & Update temp table
Create Table #Orphan_User (UserName varchar(100),UserSID varbinary(200))

INSERT INTO #Orphan_User EXEC sp_change_users_login ''report''

--Execute the cursor
DECLARE @UserName VARCHAR(500)
DECLARE @cmd NVARCHAR(500)

DECLARE orphan_cursor CURSOR FOR SELECT UserName from #Orphan_User

OPEN orphan_cursor   
FETCH NEXT FROM orphan_cursor INTO @UserName   

WHILE @@FETCH_STATUS = 0   
BEGIN
	IF EXISTS (SELECT * FROM sys.server_principals WHERE name = @UserName)
		BEGIN
		SET @cmd =''EXEC sp_change_users_login ''''auto_fix'''',''''''+@UserName+''''''''
		EXEC (@cmd)
		END
    
    ELSE
    PRINT ''Information Only: Login does not exist. Delete User and Associated Schema in Database [?]- ''+@UserName
    
	FETCH NEXT FROM orphan_cursor INTO @UserName
END

CLOSE orphan_cursor   
DEALLOCATE orphan_cursor 

-- Drop Temp Table
DROP TABLE #Orphan_User
end'
exec sp_MSforeachdb @ssql
