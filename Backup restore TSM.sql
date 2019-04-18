Step1:

EXEC master.dbo.xp_backup_database @database=[DQULISP], 
@TSMObject='SEGOTN2297-SQL2SQL2/DQULISP\dbbackup\FULL',
@TSMConfigFile='D:\SEGOTN2297-SQL2_LS\dsm.opt',
@desc='FULL Backup LS to TSM OnDemand', 
@TSMArchive=1, @init=1,
@with='COPY_ONLY'

sTEP2:

--Declare variable
Declare @TSMPointInTime varchar(20)

--Create Temp table
CREATE TABLE #TSMContents(
[File Space] nvarchar(100),
[High Level] nvarchar(20),
[Low Level] nvarchar (20),
[Management Class] varchar(20),
TsmPointInTime nvarchar(100),
backupType INT,
ServerName nvarchar(100),
DatabaseName sysname,
BackupDescription nvarchar(150),
ExpirationDate nvarchar(100)
)
--Select backup time of TSM backup taken
Insert into #TSMContents
Exec master.dbo.xp_view_tsmcontents @tsmfilespace = 'SEGOTN2297-SQL2SQL2/DQULISP',@tsmconfigfile = 'D:\SEGOTN2297-SQL2_LS\dsm.opt', @tsmarchive = 1
Set @TSMPointInTime=convert(varchar(20),(select MAX(TsmPointInTime) from #TSMContents where BackupDescription like '%OnDemand' and [Low Level]='\FULL'),120)
Drop table #TSMContents
Print @TSMPointInTime

--Kick out all the users from Database
ALTER DATABASE DQULISE SET OFFLINE WITH ROLLBACK IMMEDIATE

--Restore Database
EXEC master.dbo.xp_restore_database @database = N'DQULISE' ,
@tsmconfigfile = N'D:\SEGOTN2297-SQL2_LS\dsm.opt',
@tsmobject = N'SEGOTN2297-SQL2SQL2/DQULISP\dbbackup\FULL',
@tsmpointintime = @TSMPointInTime,
@tsmarchive = 1,
@filenumber = 1,
@with = N'REPLACE',
@with = N'STATS = 10',
@with = N'MOVE N''DQULISP_Data'' TO N''G:\Microsoft SQL Server\MSSQL.2\MSSQL\Data\DQULISE_Data.MDF''',
@with = N'MOVE N''DQULISP_Log'' TO N''G:\Microsoft SQL Server\MSSQL.2\MSSQL\Data\DQULISE_Log.LDF''',
@affinity = 0,
@logging = 0

GO





Step3:

use DQULISE
GO

DECLARE @user_name nvarchar(128), 
@login_name nvarchar(128), 
@err_msg varchar(80)

DECLARE fix_login_user INSENSITIVE CURSOR FOR
select name from sysusers where issqluser = 1 and (sid is not null and sid <> 0x0)and suser_sname(sid) is null order by name

OPEN fix_login_user FETCH NEXT FROM fix_login_user INTO @user_name

WHILE @@FETCH_STATUS = 0
	BEGIN
	SELECT @login_name = loginname FROM master.dbo.syslogins WHERE loginname = @user_name
	IF @login_name IS NULL
		BEGIN
		SELECT @err_msg = 'MATCHING LOGIN DOES NOT EXISTS FOR ' + @user_name
		PRINT @err_msg
		END
	ELSE
		BEGIN
		EXEC sp_change_users_login 'Update_One', @user_name, @login_name
		IF @@error <> 0 or @@rowcount <> 1
			BEGIN
			SELECT @err_msg = 'ERROR UPDATING LOGIN FOR ' + @user_name
			PRINT @err_msg
			END
	END
FETCH NEXT FROM fix_login_user INTO @user_name
END
CLOSE fix_login_user
DEALLOCATE fix_login_user
Go

Step4:
USE [DQULISE]
GO
CREATE USER [VCN\v008710] FOR LOGIN [VCN\v008710]
GO
USE [DQULISE]
GO
EXEC sp_addrolemember N'db_owner', N'VCN\v008710'
GO
