-- (@)# $Id: Litespeed2TSM.sql,Revision 21 - 2010/12/19 vxc9513 Exp $



-- =====================================================================
-- Author:	<Stefan Camder, Global SQL Server 3:rd team>
-- Create date: <2010-12-19>
-- Description:	<LiteSpeed2TSM >
-- Supported versions: <2005, 2008, 2008 R2>
-- =====================================================================


SET NOCOUNT ON

DECLARE @BackupErrors         INT,
        @QuestReturncode      INT,
        @SQLReturncode        INT,
        @TSMConfigFile        VARCHAR(255),
        @TSMObjName           VARCHAR(255),
        @RequestedBackupType  VARCHAR(5),
        @Dbname               SYSNAME,
        @BackupAction         VARCHAR(5),
        @BackupActionChanges  SMALLINT,
        @SQLString            NVARCHAR(4000),
        @StatusDesc           NVARCHAR(60),
        @UserAccess           NVARCHAR(60),
		@SQLversion			  NVARCHAR(128),
        @IsAccessible         CHAR(1),
		@IsNewlyRestored      CHAR(1),
		@IsBackupRunning	  CHAR(1),		
        @RecoveryModel        NVARCHAR(60),
        @FullBackupExists     CHAR(1),
        @BackupChainOK        CHAR(1),
        @PreviewMode          CHAR(1),
        @SuccessInSQLErrorLog CHAR(1),
        @StartMessage         NVARCHAR(MAX),
        @BackupMessage        NVARCHAR(MAX),
        @BackupEndMessage     NVARCHAR(MAX),
        @MsdbEndMessage       NVARCHAR(MAX),
        @EndMessage           NVARCHAR(MAX),
        @ErrorMessage         NVARCHAR(MAX),
        @StartTime            DATETIME,
        @EndTime              DATETIME,
        @BackupStartTime      DATETIME,
        @BackupEndTime        DATETIME,
        @Message              VARCHAR(255),
        @Severity             VARCHAR(13),
        @Retaindays           TINYINT,
        @Retaindate           DATETIME,
		@RetryMessage		  NVARCHAR(MAX)


-- Specify your settings here!
------------------------------------------------
SET @PreviewMode = 'N'
SET @SuccessInSQLErrorLog = 'N'
SET @Retaindays = 31
------------------------------------------------


SET @SQLversion = (SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)))

-- Check if script is running on a supported version
IF  (SELECT CAST(SUBSTRING(@SQLversion, 1, PATINDEX('%.%', @SQLversion)-1) AS TINYINT)) < 9
	BEGIN
		SET @message = 'LiteSpeed2TSM: Script does not support version: ' + CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR) + '.' + CHAR(13) + CHAR(10)
		SET @message = @message + 'Oldest supported version is SQL Server 2005 RTM (9.00.1399).' + CHAR(13) + CHAR(10)
		SET @message = @message + 'Script is terminated!'
		PRINT @message
		EXEC xp_logevent 60000, @message, warning
		RETURN
	END

-- Get TSM client node name and requested backup operation
-- Example path : set @TSMConfigFile='C:\Program Files\Tivoli\TSM\baclient\dsm.opt'
-- Requested backup operation (values allowed: FULL, DIFF, LOG)
SET @TSMConfigFile = '$(DSM_CONFIG)'
SET @RequestedBackupType = UPPER('$(DSM_BACKUPTYPE)')

-- Check if requested backup type is valid
IF  @RequestedBackupType NOT IN ('FULL','DIFF','LOG')
	BEGIN
		SET @message = 'LiteSpeed2TSM: Requested backup type ' + @RequestedBackupType + ' is invalid.' + CHAR(13) + CHAR(10)
		SET @message = @message + 'Valid types are FULL, DIFF or LOG.' + CHAR(13) + CHAR(10)
		SET @message = @message + 'Script is terminated!'
		PRINT @message
		EXEC xp_logevent 60000, @message, warning
		RETURN
	END

-- Avoid successful backup details in the SQL Server Error Log by aktivatiating global trace flg 3226. 
-- Global flag needed because of LiteSpeed bug ST#38972 "LiteSpeed incorrectly writes successful backup details to the SQL Server error log or event viewer if DBCC TRACEON (3226) is run with the backup
DECLARE  @tracestatus TABLE ( -- used to save tracestatus 
	[TraceFlag] SMALLINT,
	[Status]    BIT,
	[Global]    BIT,
	[Session]   BIT)
 
 -- Check if the 3226 is already activated
INSERT @tracestatus
EXEC( 'DBCC tracestatus (3226, -1) WITH no_infomsgs')

IF @SuccessInSQLErrorLog = 'N'
	BEGIN
		-- If the traceflag is off then activate it
		IF (SELECT status FROM @tracestatus) = 0
			DBCC traceon (3226, -1) WITH no_infomsgs
	END
ELSE
	BEGIN
		-- If the traceflag is on then deactivate it
		IF (SELECT status FROM @tracestatus) = 1
			DBCC traceoff (3226, -1) WITH no_infomsgs
	END

-- Cursor for looping though all databases
DECLARE backup_cursor CURSOR FAST_FORWARD FOR
	SELECT RTRIM([name])
	FROM   sys.databases
	WHERE  database_id <> 2 AND 
		   source_database_id IS NULL
	ORDER BY [name]


OPEN backup_cursor

SET @BackupErrors = 0
SET @BackupActionChanges = 0

-- Create header in log file
SET @StartTime = CONVERT(DATETIME,CONVERT(NVARCHAR,GETDATE(),120),120)
SET @StartMessage = 'DateTime: ' + CONVERT(NVARCHAR,@StartTime,120) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS NVARCHAR) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS NVARCHAR) + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Requested backup type: ' + @RequestedBackupType + CHAR(13) + CHAR(10)
SET @StartMessage = @StartMessage + 'Log success in SQL Error Log: ' + CASE 
																			WHEN @SuccessInSQLErrorLog = 'Y' THEN 'Yes' 
																			ELSE 'No' 
																	   END + CHAR(13) + CHAR(10)

SET @StartMessage = @StartMessage + 'Preview mode: ' + CASE 
															WHEN @PreviewMode = 'Y' THEN 'Yes (NO BACKUPS WILL BE CREATED!)' 
															ELSE 'No' 
													   END + CHAR(13) + CHAR(10)
PRINT @StartMessage
PRINT REPLICATE('=',80)

IF @PreviewMode <> 'Y'
	BEGIN
		-- Log start message in SQL Server Error log and Windows application log
		SET @message = 'LiteSpeed2TSM: ' + @RequestedBackupType + ' backup of databases started. This is an informational message only. No user action is required.'
		EXEC xp_logevent 60000, @message, informational
	END

FETCH NEXT FROM backup_cursor
INTO @Dbname

WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		SET @QuestReturncode = NULL
		SET @SQLReturncode = NULL
		SET @BackupAction = NULL
		SET @SQLString = NULL
		SET @StatusDesc = NULL
		SET @UserAccess = NULL
		SET @IsAccessible = NULL
		SET @RecoveryModel = NULL
		SET @FullBackupExists = NULL
		SET @BackupChainOK = NULL
		SET @RetryMessage = ''
	
		-- Get prerequisites for backup
		SET @StatusDesc = (SELECT state_desc FROM sys.databases WHERE name = @Dbname)
		SET @UserAccess = (SELECT user_access_desc FROM sys.databases WHERE name = @Dbname)
		
		-- Check if the database is accessible
		SET @IsAccessible = CASE
								WHEN (SELECT database_guid 
									  FROM sys.database_recovery_status 
									  WHERE DB_NAME(database_id) = @Dbname) IS NOT NULL THEN 'Y' 
								ELSE 'N' 
							END
		SET @RecoveryModel =  (SELECT recovery_model_desc FROM sys.databases WHERE name = @Dbname)
		
		-- Check if a full backup exists
		SET @FullBackupExists = CASE
									WHEN (SELECT MAX(backup_finish_date) 
										  FROM msdb..backupset 
										  WHERE  type = 'D' AND description = 'Full Backup LS to TSM' AND database_name = @Dbname) IS NOT NULL THEN 'Y' 
									ELSE 'N' 
								END

		-- Check if the backup chain is ok and that no one has issued a full/transaction log backup without using COPY_ONLY option
		SET @BackupChainOK = CASE
								 WHEN ((SELECT last_log_backup_lsn 
									    FROM sys.database_recovery_status 
								 	    WHERE DB_NAME(database_id) = @Dbname) IS NOT NULL 
										 AND
									    NOT EXISTS (SELECT backup_finish_date
												    FROM msdb..backupset 
												    WHERE  type IN ('D', 'L') AND 
														   is_copy_only = 0 AND
														   ISNULL(description, 'Unknown') NOT IN ('Full Backup LS to TSM', 'Log Backup LS to TSM') AND 
														   database_name = @Dbname AND 
														   backup_finish_date >= (SELECT MAX(backup_finish_date) 
																				  FROM msdb..backupset 
																				  WHERE  type = 'D' AND 
																				    	 description = 'Full Backup LS to TSM' AND 
																						 database_name = @Dbname)))  THEN 'Y' 
		        				 ELSE 'N' 
							 END

		--Check if the database is newly restored
		SET @IsNewlyRestored = CASE
								   WHEN (SELECT MAX(restore_date)
										 FROM msdb..restorehistory
										 WHERE destination_database_name = @Dbname) > (SELECT MAX(backup_finish_date) 
										   											   FROM msdb..backupset 
																					   WHERE description = 'Full Backup LS to TSM' AND database_name = @Dbname) THEN 'Y'
								   ELSE 'N'
							   END
							   
		--Check if the database is already involved in a backup/restore process
		SET @IsBackupRunning = CASE
								   WHEN (SELECT command
										 FROM sys.dm_exec_requests r
										 CROSS APPLY sys.dm_exec_sql_text(r.sql_handle)
										 WHERE DB_NAME(r.database_id) = @Dbname AND r.command in ('BACKUP DATABASE', 'BACKUP LOG')) IS NOT NULL THEN 'Y'
								   ELSE 'N'
							   END
						   
		SET @SQLString = ''
			
		IF @StatusDesc IN ('ONLINE') AND 
		   @UserAccess IN ('MULTI_USER','RESTRICTED_USER') AND 
		   @IsAccessible = 'Y' AND 
		   @IsBackupRunning = 'N'
			BEGIN
				-- Generate final backup action depending on requested backup operation and agreed rules for substitution
				SET @BackupAction =	CASE
										-- Full backup for all databases
										WHEN @RequestedBackupType IN ('FULL') AND 
											 @RecoveryModel IN ('FULL','SIMPLE','BULK_LOGGED') AND 
											 @IsNewlyRestored IN ('Y','N') AND
											 @FullBackupExists IN ('Y','N') AND
											 @BackupChainOK IN ('Y','N') THEN 'FULL'

										-- Diff backup for all databases except Master and Msdb and Model
										WHEN @RequestedBackupType IN ('DIFF') AND 
											 @RecoveryModel IN ('FULL','SIMPLE','BULK_LOGGED') AND 
											 @IsNewlyRestored IN ('N') AND
											 @FullBackupExists IN ('Y') AND
											 @BackupChainOK IN ('Y','N') AND
											 @Dbname NOT IN ('MASTER','MSDB','MODEL') THEN 'DIFF'

										-- Log backup for all databases except Master and Msdb
										WHEN @RequestedBackupType IN ('LOG') AND 
											 @RecoveryModel IN ('FULL','BULK_LOGGED') AND 
											 @IsNewlyRestored IN ('N') AND
											 @FullBackupExists IN ('Y') AND
											 @BackupChainOK IN ('Y') AND
											 @Dbname NOT IN ('MASTER','MSDB') THEN 'LOG'
										
										-- Change Diff to Full for Master and Msdb and Model
										WHEN @RequestedBackupType IN ('DIFF') AND
											 @Dbname IN ('MASTER','MSDB','MODEL') THEN 'FULL'

										-- Change Diff to Full for all databases when no full backup exists 
										WHEN @RequestedBackupType IN ('DIFF') AND
											 @FullBackupExists IN ('N') THEN 'FULL'

										-- Change Log/Diff to Full for all databases when database is newly restored
										WHEN @RequestedBackupType IN ('LOG', 'DIFF') AND
											 @IsNewlyRestored IN ('Y') THEN 'FULL'
			
										-- Change Log to Full for all databases except Master and Msdb and Model when the backup chain is broken 
										WHEN @RequestedBackupType IN ('LOG') AND 
											 @RecoveryModel IN ('FULL','BULK_LOGGED') AND 
											 @FullBackupExists IN ('Y') AND
											 @BackupChainOK IN ('N') AND
											 @Dbname NOT IN ('MASTER','MSDB','MODEL') THEN 'FULL'
											 
										-- Change Log to Full for all databases except Master and Msdb and Model when no full backup exists
										WHEN @RequestedBackupType IN ('LOG') AND 
											 @RecoveryModel IN ('FULL','BULK_LOGGED') AND 
											 @FullBackupExists IN ('N') AND
											 @BackupChainOK IN ('Y','N') AND
											 @Dbname NOT IN ('MASTER','MSDB','MODEL') THEN 'FULL'											 
									
										ELSE ''
									END
			END
		
		-- Track backup action changes
		IF @BackupAction NOT IN (@RequestedBackupType, '')
			SET @BackupActionChanges = @BackupActionChanges +1		
									
		-- Generate TSM objectname for the database.
		SET @TSMObjName = REPLACE(@@SERVERNAME,'\','') + '/' + @Dbname + '\dbbackup\' + @BackupAction

		-- Generate backup command
		SET @SQLString = CASE
							 WHEN @BackupAction = 'FULL' THEN N'master.dbo.xp_backup_database @database =' + QUOTENAME(@Dbname) + ', @TSMObject = ''' + @TSMObjName + ''', @TSMConfigFile = ''' + @TSMConfigFile + ''', @desc = ''Full Backup LS to TSM'', @TSMArchive = 1, @init = 1'
							 WHEN @BackupAction = 'DIFF' THEN N'master.dbo.xp_backup_database @database =' + QUOTENAME(@Dbname) + ', @TSMObject = ''' + @TSMObjName + ''', @TSMConfigFile = ''' + @TSMConfigFile + ''', @desc = ''Diff Backup LS to TSM'', @TSMArchive = 1, @init = 1, @with = ''DIFFERENTIAL''' 
							 WHEN @BackupAction = 'LOG'  THEN N'master.dbo.xp_backup_log @database =' + QUOTENAME(@Dbname) + ', @TSMObject = ''' + @TSMObjName + ''', @TSMConfigFile = ''' + @TSMConfigFile + ''', @desc = ''Log Backup LS to TSM'', @TSMArchive = 1, @init = 1'
							 ELSE ''
					     END

		-- Create backup information in log file
		SET @BackupMessage = 'DateTime: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Database: ' + QUOTENAME(@Dbname) + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Status: ' + @StatusDesc + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Mirroring role: ' + ISNULL((SELECT mirroring_role_desc FROM sys.database_mirroring WHERE database_id = DB_ID(@Dbname)),'None') + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Standby: ' + CASE 
																WHEN (SELECT is_in_standby 
																	  FROM sys.databases 
																	  WHERE name = @Dbname) = 1 THEN 'Yes' 
																ELSE 'No' 
															END + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Updateability: ' + CASE 
																	  WHEN (SELECT is_read_only 
																			FROM sys.databases 
																			WHERE name = @Dbname) = 1 THEN 'No' 
																	  ELSE 'Yes' 
																  END + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'User access: ' + @UserAccess + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Is accessible: ' + CASE 
																	  WHEN @IsAccessible = 'Y' THEN 'Yes' 
																	  ELSE 'No' 
																  END + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Is newly restored: ' + CASE 
																		  WHEN @IsNewlyRestored = 'Y' THEN 'Yes'
																		  ELSE 'No'
																	  END + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Recovery model: ' + @RecoveryModel + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Full backup exists: ' + CASE 
																		   WHEN @FullBackupExists = 'Y' THEN 'Yes' 
																		   ELSE 'No' 
																		END + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Backup chain ok: ' + CASE 
																		WHEN @BackupChainOK = 'Y' THEN 'Yes' 
																		ELSE 'No' 
																	END + CHAR(13) + CHAR(10)
																	
		SET @BackupMessage = @BackupMessage + 'Backup running: ' + CASE 
																		WHEN @IsBackupRunning = 'Y' THEN 'Yes' 
																		ELSE 'No' 
																	END + CHAR(13) + CHAR(10)																	
																			
		SET @BackupMessage = @BackupMessage + 'Backup action: ' + CASE 
																	  WHEN @BackupAction = '' THEN 'None (action not required)' 
																	  WHEN (@StatusDesc NOT IN ('ONLINE') OR 
																			@UserAccess NOT IN ('MULTI_USER','RESTRICTED_USER') OR 
																			@IsAccessible = 'N') THEN 'None (database not accessible for backup)' 
																	  WHEN @IsBackupRunning = 'Y' THEN 'None (Backup process already running)'
																	  WHEN @BackupAction <> @RequestedBackupType THEN 'Changed from ' + @RequestedBackupType + ' to ' + @BackupAction 
																	  ELSE @BackupAction 
																  END + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
		SET @BackupMessage = @BackupMessage + 'Command: ' + CASE 
																WHEN @SQLString = '' THEN CHAR(13) + CHAR(10) 
																ELSE @SQLString 
															END
		SET @BackupMessage = REPLACE(@BackupMessage,'%','%%')
		PRINT @BackupMessage
		
        SET @BackupStartTime = CONVERT(datetime,CONVERT(nvarchar,GETDATE(),120),120)

		IF @SQLString <> ''  
			IF @PreviewMode <> 'Y' AND 
			   @StatusDesc IN ('ONLINE') AND 
			   @UserAccess IN ('MULTI_USER','RESTRICTED_USER') AND 
			   @IsAccessible = 'Y' AND
			   @IsBackupRunning = 'N'
				BEGIN
					BEGIN TRY
						-- If not exists Create LiteSpeed status table in TempDB
						IF OBJECT_ID('tempdb..LiteSpeedStatus','U') IS NULL
								CREATE TABLE tempdb..LiteSpeedStatus (
										[dbname]		SYSNAME     NOT NULL,
										[backupType]	VARCHAR(50) NOT NULL,
										[returncode]	INT			NOT NULL,
										[errortime]		DATETIME    NOT NULL)
								
						-- Wrapper in order to include error handling.
						-- SOL31940 - LiteSpeed Extended Stored Procedures are not supported with the the SQL 2005 TRY EXCEPT and CATCH 
						SET @SQLString = N' EXEC @QuestReturncode = ' + @SQLString + '
											IF @QuestReturncode <> 0  
												INSERT INTO tempdb..LiteSpeedStatus (dbname, BackupType, returncode, errortime)
												VALUES (''' + @Dbname + ''',''' + @RequestedBackupType + ''',@QuestReturncode, GETDATE())'
													
						-- Execute the backup command and fetch return code
						EXEC  sp_executesql @SQLString, N'@QuestReturncode int output', @SQLReturncode output

						-- If the backup failed let's try one more time /Stefan Camder 2012-08-27
						IF @SQLReturncode <> 0
						BEGIN
							PRINT ' ' + CHAR(13) + CHAR(10)
							EXEC  sp_executesql @SQLString, N'@QuestReturncode int output', @SQLReturncode output
							SET @RetryMessage = 'Comment: This was a second attempt to backup the database.'
							
						END
						-- Check if previous backup failed and this is successful
						IF (SELECT MAX(backup_finish_date) 
							FROM msdb.dbo.backupset 
							WHERE database_name = @Dbname) > (SELECT MAX(errortime)
															  FROM   tempdb..LiteSpeedStatus
															  WHERE  dbname = @Dbname AND returncode <> 0)
							BEGIN
								-- Log success message in SQL Server Error log and Windows application log
								SET @message = 'Database backed up. Database: ' + @Dbname + ', creation date(time): ' + CONVERT(NVARCHAR(30),GETDATE(),111) + '(' + CONVERT(NVARCHAR(30),GETDATE(),108) + '). This is an informational message only. No user action is required.'
								EXEC xp_logevent 60000, @message, informational
                      
								-- Delete rows for the actual database in LiteSpeedStatus
								DELETE FROM tempdb..LiteSpeedStatus
								WHERE       dbname = @Dbname
							END
										
						-- Check if the requested backup operation failed
	                   	IF @SQLReturncode <> 0
							-- Break the begin try block
							RAISERROR ('Litespeed return code %d',16,1,@SQLReturncode)
						ELSE
							-- Create success information in log file
							PRINT CHAR(13)
				END TRY
                BEGIN CATCH
					-- Create error information in log file
					SET @ErrorMessage = CHAR(13) + CHAR(10)
					SET @ErrorMessage = @ErrorMessage + 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR) + CHAR(13) + CHAR(10)
					SET @ErrorMessage = @ErrorMessage + 'Error Message: ' + ERROR_MESSAGE() + CHAR(13) + CHAR(10)
					SET @ErrorMessage = @ErrorMessage + 'Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR) + CHAR(13) + CHAR(10)
					SET @ErrorMessage = @ErrorMessage + 'Error State: ' + CAST(ERROR_STATE() AS VARCHAR) + CHAR(13) + CHAR(10)
					SET @ErrorMessage = @ErrorMessage + 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
					SET @ErrorMessage = REPLACE(@ErrorMessage,'%','%%')
					PRINT @ErrorMessage
				
					-- Track errors
					SET @BackupErrors = @BackupErrors + 1				
				END CATCH 
			END
			
			-- -- Create error information in log file
			SET @BackupEndTime = CONVERT(datetime,CONVERT(varchar,GETDATE(),120),120)
			SET @BackupEndMessage = 'Outcome: ' + CASE 
													  WHEN @SQLReturncode IS NULL THEN '' 
													  WHEN @SQLReturncode = 0 THEN 'Succeeded' 
													  ELSE 'Failed' 
												  END + CHAR(13) + CHAR(10)
			SET @BackupEndMessage = @BackupEndMessage + 'Duration: ' + CASE 
																		   WHEN DATEDIFF(ss,@BackupStartTime, @BackupEndTime)/(24*3600) > 0 THEN CAST(DATEDIFF(ss,@BackupStartTime, @BackupEndTime)/(24*3600) AS NVARCHAR) + '.' 
																		   ELSE '' 
																		END + CONVERT(NVARCHAR,@BackupEndTime - @BackupStartTime,108) + CHAR(13) + CHAR(10)
			SET @BackupEndMessage = @BackupEndMessage + 'DateTime: ' + CONVERT(nvarchar,@BackupEndTime,120) + CHAR(13) + CHAR(10)
			SET @BackupEndMessage = @BackupEndMessage + @RetryMessage + CHAR(13) + CHAR(10)
			SET @BackupEndMessage = REPLACE(@BackupEndMessage,'%','%%')
			PRINT @BackupEndMessage
   
		FETCH NEXT FROM backup_cursor
		INTO @Dbname
		IF @@FETCH_STATUS <> -1
			PRINT REPLICATE('-',80)
	END

CLOSE backup_cursor
DEALLOCATE backup_cursor

IF @PreviewMode <> 'Y'
BEGIN
	BEGIN TRY
		-- Clean msdb History
		PRINT REPLICATE('-',80)
		PRINT 'Post backup action: Cleaning msdb history' 
		SET @Retaindate = DATEADD(d,-@Retaindays,GETDATE())
		EXEC @SQLReturncode = msdb.dbo.sp_delete_backuphistory @Retaindate
		
		-- Check if cleaning Msdb failed
	    IF @SQLReturncode <> 0
			-- Break the begin try block
			RAISERROR ('Litespeed return code %d',16,1,@SQLReturncode)
				ELSE
					BEGIN
						-- Create success information in log file
						SET @MsdbEndMessage = 'Number of retaining days: ' + CAST(@retaindays AS VARCHAR) + CHAR(13) + CHAR(10)
						SET @MsdbEndMessage = @MsdbEndMessage +  'Oldest date retained: ' + CAST(@retaindate AS VARCHAR) + CHAR(13) + CHAR(10)
						SET @MsdbEndMessage = @MsdbEndMessage +  CHAR(13) + CHAR(10)
						SET @MsdbEndMessage = @MsdbEndMessage +  'Outcome: Succeeded' + CHAR(13) + CHAR(10)
						PRINT @MsdbEndMessage
					END
	END TRY
	BEGIN CATCH
		-- Create error information in log file
		SET @ErrorMessage = + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR) + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error Message: ' + ERROR_MESSAGE() + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR) + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error State: ' + CAST(ERROR_STATE() AS VARCHAR) + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR) + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Error Proc: ' + ERROR_PROCEDURE() + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
		SET @ErrorMessage = @ErrorMessage + 'Outcome: Failed'
		SET @ErrorMessage = REPLACE(@ErrorMessage,'%','%%')
		PRINT @ErrorMessage
	
		-- Track errors
		SET @BackupErrors = @BackupErrors + 1
	END CATCH
END

-- Create footer in log file
PRINT REPLICATE('=',80)
SET @EndTime = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),120),120)
SET @EndMessage = 'Total duration: ' + CASE 
										   WHEN DATEDIFF(ss,@StartTime, @EndTime)/(24*3600) > 0 THEN CAST(DATEDIFF(ss,@StartTime, @EndTime)/(24*3600) AS NVARCHAR) + '.' 
										   ELSE '' 
									   END + CONVERT(NVARCHAR,@EndTime - @StartTime,108) + CHAR(13) + CHAR(10)
SET @EndMessage = @EndMessage + 'DateTime: ' + CONVERT(NVARCHAR,@EndTime,120) + CHAR(13) + CHAR(10)
SET @EndMessage = @EndMessage + 'Number of backup action changes: ' + CAST(@BackupActionChanges AS VARCHAR(5)) + CHAR(13) + CHAR(10)
SET @EndMessage = @EndMessage + 'Number of errors: ' + CAST(@BackupErrors AS VARCHAR(5))
SET @EndMessage = REPLACE(@EndMessage,'%','%%')
PRINT @EndMessage

-- Create summary message
SET @severity = 'warning'
IF @PreviewMode <> 'Y'
	BEGIN
		IF @BackupErrors > 0
			SET @message = 'LiteSpeed2TSM: ' + @RequestedBackupType + ' backup of databases completed with ' + CONVERT(VARCHAR(5),@BackupErrors) + ' Errors!'
		ELSE
			BEGIN
				SET @message = 'LiteSpeed2TSM: ' + @RequestedBackupType + ' backup of databases completed Successfully. This is an informational message only. No user action is required.'
				SET @severity = 'informational'
			END
		END
	ELSE
		SET @message = 'LiteSpeed2TSM: is running in preview mode. No backups will be created!'
	
	
PRINT @message

-- Log end message in SQL Server Error log and Windows application log
EXEC xp_logevent 60000, @message, @severity

PRINT REPLICATE('=',80)

:exit(select @BackupErrors) 