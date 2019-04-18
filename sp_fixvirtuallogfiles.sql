USE [VIT_GLOBAL_TOOLBOX]
GO

/****** Object:  StoredProcedure [dbo].[sp_FixVirtualLogFiles]    Script Date: 11/30/2012 05:45:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_FixVirtualLogFiles]
	@Databases	sysname,
	@Action varchar(14) = 'Scan', 
	@TargetMinLogSizeMb int = 10, 
	@TargetGrowthType varchar(2) = 'MB',			
	@MaxReallocationIncrementSizeMb float = 8000,
	@MaxNumberOfVLFs int = 50,				
	@MaxVLFsizeMb int = 512,
	@BackupHistoryDays int = 7,
	@DatabaseHasToExistDays int = 7,
	@LogSizeLevel1 int =500,
	@LogSizeLevel2 int = 2500,
	@AutoGrowthLow int = 60,
	@AutoGrowthMedium int = 250,
	@AutoGrowthHigh int = 500,
	@Database_id_out int = NULL OUTPUT,
	@DatabaseName_out sysname = NULL OUTPUT,
	@RecoveryModel_out nvarchar(128) = NULL OUTPUT,
	@LogFileName_out sysname = NULL OUTPUT,
	@CurrentLogSizeMb_out int = NULL OUTPUT,
	@TargetLogSizeMb_out int = NULL OUTPUT,
	@CurrentAutoGrowth_out int = NULL OUTPUT,
	@CurrentAutoGrowthEnabled_out char(1) = NULL OUTPUT,
	@CurrentGrowthType_out varchar(2) = NULL OUTPUT,
	@CurrentNumberOfVLFs_out int = NULL OUTPUT,
	@CurrentAvgVLFs_out int = NULL OUTPUT,
	@CurrentMaxVLFs_out int = NULL OUTPUT,
	@LogSizeFileId_out tinyint = NULL OUTPUT						
AS

BEGIN
	SET NOCOUNT ON
	
	DECLARE @Database_id					int,
			@DatabaseName					sysname,
			@TargetDatabase					sysname,
			@RecoveryModel					nvarchar(128),
			@TotalDataFilesSizeMb			int,
			@LogFileName					sysname,
			@NoOfLogFiles					tinyint,
			@LogfileNr						tinyint,
			@LogFileOrgCreateSize			int,
			@CurrentLogSizeMb				int,
			@CurrentLogUsedMb				int,
			@CurrentAutoGrowth				int,
			@CurrentAutoGrowthEnabled		char(1),
			@CurrentGrowthType				varchar(2),
			@CurrentNumberOfVLFs			int,
			@CurrentAvgVLFs					int,
			@CurrentMaxVLFs					int,
			@TargetLogSizeMb				int,
			@AdjustedTargetLogSizeMb		int,
			@TargetAutogrowth				int,
			@LogSizeFileId					tinyint,
			@Sql							varchar(512),
			@LogFileBuildSize				int,
			@LogShrinkableSize				int,
			@NextFreeVLFSize				int,
			@Growth							int,
			@Step							int,
			@Loop							tinyint,
			@StatusDesc						nvarchar(60),
			@UserAccess						nvarchar(60),
			@IsAccessible					char(1),
			@SQLversion						nvarchar(128),
			@Message						varchar(255),
			@NoCommandsGenerated			int,
			@MaxLogBackupSizeMb				int,
			@create_date					datetime
			
	
	-- Check input parameters
	SET @message = NULL
	SET @message = 'Invalid parameter value: ' + CASE
													WHEN @Databases IS NULL THEN '@Databases = ' + ISNULL(@Databases, 'NULL') + '. @Databases cannot be ''NULL''.'
													WHEN @Databases <>'' AND (SELECT name FROM sys.databases WHERE name = @Databases) IS NULL THEN '@Databases = ' + @Databases + '. Database does not exist!'
													WHEN UPPER(@Action) NOT IN ('SCAN', 'FIX', 'SIMULATE', 'REPORT', 'REPORT_OUTPUT') THEN '@Action = ' + @Action + '. Valid actions are [''Report''|''Simulate''|''Fix''|''Scan''|''Report_output''].'
													WHEN @TargetMinLogSizeMb = 0 OR @TargetMinLogSizeMb IS NULL THEN '@TargetMinLogSizeMb = ' + CAST(@TargetMinLogSizeMb AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @BackupHistoryDays = 0 OR @BackupHistoryDays IS NULL THEN '@BackupHistoryDays = ' + CAST(@BackupHistoryDays AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @DatabaseHasToExistDays = 0 OR @DatabaseHasToExistDays IS NULL THEN '@DatabaseHasToExistDays = ' + CAST(@DatabaseHasToExistDays AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @LogSizeLevel1 = 0 OR @LogSizeLevel1 IS NULL THEN '@LogSizeLevel1 = ' + CAST(@LogSizeLevel1 AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @LogSizeLevel2 = 0 OR @LogSizeLevel2 IS NULL THEN '@LogSizeLevel2 = ' + CAST(@LogSizeLevel2 AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @AutoGrowthLow = 0 OR @AutoGrowthLow IS NULL THEN '@AutoGrowthLow = ' + CAST(@AutoGrowthLow AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @AutoGrowthMedium = 0 OR @AutoGrowthMedium IS NULL THEN '@AutoGrowthMedium = ' + CAST(@AutoGrowthMedium AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN @AutoGrowthHigh = 0 OR @AutoGrowthHigh IS NULL THEN '@AutoGrowthHigh = ' + CAST(@AutoGrowthHigh AS varchar(256)) + '. Valid value is ''1'' or bigger.'
													WHEN UPPER(@TargetGrowthType) NOT IN ('MB','%') THEN '@TargetGrowthType = ' + @TargetGrowthType + '. Valid values are [''MB''|''%%''].'
													WHEN @MaxReallocationIncrementSizeMb = 4096 OR @MaxReallocationIncrementSizeMb NOT BETWEEN 1 AND 8000 THEN '@MaxReallocationIncrementSizeMb = ' +CAST(@MaxReallocationIncrementSizeMb AS varchar(256)) + '. Valid values are between ''1'' and ''8000'' with exception of ''4096''.'
													WHEN @MaxNumberOfVLFs NOT BETWEEN 1 AND 50 THEN '@MaxNumberOfVLFs = ' + CAST(@MaxNumberOfVLFs AS varchar(256)) + '. Valid values are between ''1'' and ''50''.'
													WHEN @MaxVLFsizeMb NOT BETWEEN 1 AND 512 THEN '@MaxVLFsizeMb = ' + CAST(@MaxVLFsizeMb AS varchar(256)) + '. Valid values are between ''1'' and ''512''.'
												 END
	IF @message IS NOT NULL
		BEGIN
			RAISERROR(@message, 11, 1)
			RETURN
		END 

	 -- Check permissions, DBCC LOGINFO requires sysadmin 
	IF IS_SRVROLEMEMBER('sysadmin') = 0
		BEGIN
			SET @message = 'This procedure requires sysadmin priviledges to run'
			RAISERROR(@message,11,1)
			RETURN
		END
	
	SET @SQLversion = (SELECT CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)))

	-- Check if script is running on a supported version
	IF  (SELECT CAST(SUBSTRING(@SQLversion, 1, PATINDEX('%.%', @SQLversion)-1) AS TINYINT)) < 9
		BEGIN
			SET @message = 'Script does not support version: ' + CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR) + '.' + CHAR(13) + CHAR(10)
			SET @message = @message + 'Oldest supported version is SQL Server 2005 RTM (9.00.1399).' + CHAR(13) + CHAR(10)
			SET @message = @message + 'Script is terminated!'
			RAISERROR(@message, 11, 1)
			RETURN
		END
		
	-- Check if @MaxReallocationIncrementSizeMb will violate @MaxVLFsizeMb
	IF CASE 
		   WHEN @MaxReallocationIncrementSizeMb > 0 AND @MaxReallocationIncrementSizeMb <= 64 THEN @MaxReallocationIncrementSizeMb / 4
		   WHEN @MaxReallocationIncrementSizeMb > 64 AND @MaxReallocationIncrementSizeMb <= 1000 THEN @MaxReallocationIncrementSizeMb / 8
		   WHEN @MaxReallocationIncrementSizeMb > 1000 THEN @MaxReallocationIncrementSizeMb / 16
	   END 	> @MaxVLFsizeMb
		BEGIN
			SET @message = '@MaxReallocationIncrementSizeMb set to ' + CAST(@MaxReallocationIncrementSizeMb AS varchar(256)) + ' MB is too big. It will create VLFs bigger than @MaxVLFsizeMb (' + CAST(@MaxVLFsizeMb AS varchar(256)) + ' MB)'
			RAISERROR(@message, 11, 1)
			RETURN
		END 

		-- Table vaiable for log files details
		DECLARE @LogFileOverviewTable TABLE
		(
			[Database_id] int,
			[Database] nvarchar(max),
			[Object] varchar(256),
			[Current Value] sql_variant,
			[Target Value] sql_variant default '',
			[Adjusted Target Value] sql_variant default '',
			[Action] varchar(256) default '',
			[New Value] sql_variant
		)
		
		-- Table vaiable for VLF details
		DECLARE @VlfDetailTable TABLE
		(
			[FileId] int NOT NULL,
			[FileSize] bigint NOT NULL,
			[StartOffset] bigint NOT NULL,
			[FSeqNo] bigint NOT NULL,
			[Status] bigint NOT NULL,
			[Parity] bigint NOT NULL,
			[CreateLSN] numeric(38) NOT NULL	
		)

	IF (SELECT CURSOR_STATUS('local','cursor_Databases')) = 1
		BEGIN
			CLOSE cursor_Databases
			DEALLOCATE cursor_Databases
		END
	
	SET @NoCommandsGenerated = 0
	
	-- Loop through all the databases		
	DECLARE cursor_Databases CURSOR LOCAL STATIC READ_ONLY FOR
	   SELECT d.name, d.create_date
	   FROM sys.databases d
	   WHERE --d.state = 0 AND
	   (@Databases = '' OR d.name = @Databases)
	   ORDER BY d.name
	   
	OPEN cursor_Databases
	FETCH NEXT FROM cursor_Databases INTO @TargetDatabase, @create_date
	
	WHILE (@@FETCH_STATUS = 0)
		BEGIN
			-- Check if the database is online
			SET @StatusDesc = (SELECT state_desc FROM sys.databases WHERE name = @TargetDatabase)
			
			-- Check user access
			SET @UserAccess = (SELECT user_access_desc FROM sys.databases WHERE name = @TargetDatabase)
			
			-- Check if the database is accessible
			SET @IsAccessible = CASE
									WHEN (SELECT database_guid 
										  FROM sys.database_recovery_status 
										  WHERE DB_NAME(database_id) = @TargetDatabase) IS NOT NULL THEN 'Y' 
									ELSE 'N' 
								END
								
			IF @StatusDesc IN ('ONLINE') AND 
			   @UserAccess IN ('MULTI_USER','RESTRICTED_USER') AND 
			   @IsAccessible = 'Y' 
				BEGIN
					DELETE @VlfDetailTable
									
					SET @SQL = 'DBCC LOGINFO(' + QUOTENAME(@TargetDatabase) + ') WITH TABLERESULTS, NO_INFOMSGS'
					-- Save VLF details, The DBCC below output one row for each log fragment (VLF)
					INSERT INTO @VlfDetailTable ([FileId], [FileSize], [StartOffset], [FSeqNo], [Status], [Parity], [CreateLSN])
					EXEC(@SQL)
					IF @@ERROR <> 0
						BEGIN
							SET @message = 'Error collecting Transaction Log fragmentation info'
							RAISERROR(@message, 11, 2)
							RETURN
						END
					
					-- Get total data files size
					SET @TotalDataFilesSizeMb = (SELECT SUM(CAST(size * 8 / 1024 AS float)) FROM sys.master_files WHERE DB_NAME(database_id) = @TargetDatabase and type in ( 0, 2, 4 ))

					-- Get max log file backup size during @BackupHistoryDays for databases existing more than @DatabaseHasToExistDays
					SET @MaxLogBackupSizeMb = (SELECT MAX(CEILING([backup_size] / 1048576.0))
											FROM [msdb].[dbo].[backupset] b INNER JOIN sys.databases d
												ON  b.database_name = d.name
											WHERE database_name = @TargetDatabase AND 
												type = 'L' AND
												DATEDIFF(dd, b.backup_finish_date, GETDATE()) <= @BackupHistoryDays AND
												DATEDIFF(dd, d.create_date, GETDATE()) >= @DatabaseHasToExistDays)
			
					-- Rules for calculating @TargetLogSizeMb
					SET @TargetLogSizeMb = CASE 
											   WHEN @MaxLogBackupSizeMb < @TargetMinLogSizeMb THEN @TargetMinLogSizeMb
											   ELSE @MaxLogBackupSizeMb
										   END
					-- Get number of log files in @TargetDatabase				   
					SET @NoOfLogFiles = (SELECT COUNT(file_id) FROM sys.master_files
															   WHERE DB_NAME(database_id) = @TargetDatabase AND type_desc = 'LOG')

					SET @LogFileNr = 0
								
					IF (SELECT CURSOR_STATUS('local','cursor_LogFiles')) = 1
						BEGIN
							CLOSE cursor_LogFiles
							DEALLOCATE cursor_LogFiles
						END
				
					-- Loop through all log file in the actual database
					DECLARE cursor_LogFiles CURSOR LOCAL STATIC READ_ONLY FOR
						SELECT  database_id,
								@TargetDatabase AS 'Database',
								CAST(DATABASEPROPERTYEX(@TargetDatabase,'Recovery') AS sysname) AS 'Recovery Model',
								name AS 'Log file', 
								CAST(size * 8 / 1024 AS int) AS 'Current Log Size [MB]',
								-- to deal with databases with more than one transaction log, even tough no one should be doing 
								-- this. In this case the @TargetLogSizeMb will be proportionally divided for all 
								-- files. The end total might be slightly higher due to rounding.
								CAST(ROUND(ISNULL((@TargetLogSizeMb * SUM([FileSize]) / (SELECT SUM([FileSize]) FROM @VlfDetailTable)), CEILING(SUM([FileSize]) / 1048576.0)), 0) AS int) AS 'Target Log Size [MB]',
								CASE 
									 WHEN growth > 0
									 THEN CASE
											  WHEN [is_percent_growth]= 1 
											  THEN growth
											  ELSE CAST(growth * 8 / 1024 AS int)
										  END
								END AS 'Current Auto growth',
								CASE
									WHEN growth > 0
									THEN 'Y'
									ELSE 'N'
								END AS 'Current Auto growth enabled',
								CASE
									 WHEN growth > 0
									 THEN CASE
											  WHEN [is_percent_growth]= 1 
											  THEN '%'
											  ELSE 'MB'
										  END
								 END AS 'Current Growth type',
								 CAST(COUNT(v.[FileId]) AS int) AS 'Current Number of VLFs',
								 CAST(CEILING(AVG([FileSize] / 1048576.0)) AS int) AS 'Current Avg VLF size [MB]',
								 CAST(CEILING(MAX([FileSize] / 1048576.0)) AS int) AS 'Current Max VLF size [MB]',
								 mf.file_id
						FROM @VlfDetailTable v JOIN sys.master_files mf 
						ON v.[FileId] = mf.file_id
						WHERE DB_NAME(database_id) = @TargetDatabase
						GROUP BY database_id, name, growth, mf.file_id, size, is_percent_growth
						ORDER BY mf.file_id

					OPEN cursor_LogFiles
				      
					FETCH NEXT FROM cursor_LogFiles INTO 
						@Database_id,
						@DatabaseName, 
						@RecoveryModel,
						@LogFileName, 
						@CurrentLogSizeMb, 
						@TargetLogSizeMb,
						@CurrentAutoGrowth, 
						@CurrentAutoGrowthEnabled, 
						@CurrentGrowthType, 
						@CurrentNumberOfVLFs, 
						@CurrentAvgVLFs, 
						@CurrentMaxVLFs,
						@LogSizeFileId				

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @LogShrinkableSize = NULL
							SET @AdjustedTargetLogSizeMb = NULL
														
							SET @LogFileNr = @LogFileNr + 1
							
							-- Get original create size of the log file
							SET @LogFileOrgCreateSize = CAST(ISNULL((SELECT CEILING(SUM(v.[FileSize] / 1048576.0))
																				 FROM @VlfDetailTable v JOIN sys.master_files mf
																				 ON v.[FileId] = mf.file_id
																				 WHERE DB_NAME(database_id) = @TargetDatabase AND mf.file_id = @LogSizeFileId AND v.CreateLSN = 0),0) AS int)
						
							-- Get used size of the log file
							SET @CurrentLogUsedMb = CAST(ISNULL((SELECT CEILING(SUM(v.[FileSize] / 1048576.0))
																				 FROM @VlfDetailTable v JOIN sys.master_files mf
																				 ON v.[FileId] = mf.file_id
																				 WHERE DB_NAME(database_id) = @TargetDatabase AND mf.file_id = @LogSizeFileId AND status = 2),0) AS int)
												
							-- Get shrinkable size of the log file
							SET @LogShrinkableSize = CAST(ISNULL((SELECT FLOOR(SUM(v.[FileSize] / 1048576.0))
																				 FROM @VlfDetailTable v JOIN sys.master_files mf 
																				 ON v.[FileId] = mf.file_id
																				 WHERE DB_NAME(database_id) = @TargetDatabase AND mf.file_id = @LogSizeFileId AND status = 0 and StartOffset > (SELECT max(StartOffset) FROM @VlfDetailTable WHERE status = 2)),0) AS int)
							
							-- Check if reusable VLFs exist before last active VLF
							IF 	NOT EXISTS (SELECT v.[FileSize]
											FROM @VlfDetailTable v JOIN sys.master_files mf 
											ON v.[FileId] = mf.file_id
											WHERE DB_NAME(database_id) = @TargetDatabase AND mf.file_id = @LogSizeFileId AND v.Status = 0 AND StartOffset < (SELECT max(StartOffset) FROM @VlfDetailTable WHERE Status = 2))
								BEGIN	 
									WITH CTE_VLFs AS
									(				
										SELECT ROW_NUMBER() over (order by startoffset) AS 'RowNumber', v.*
										FROM @VlfDetailTable v JOIN sys.master_files mf
										ON v.[FileId] = mf.file_id	
										WHERE DB_NAME(database_id) = @TargetDatabase AND mf.file_id = @LogSizeFileId
									)
									
									-- Get the size of the next free VLF after last active
									SELECT @NextFreeVLFSize = (
									SELECT CAST(ISNULL((SELECT CEILING([FileSize] / 1048576.0)
									FROM CTE_VLFs
									WHERE Status = 0 and  RowNumber = (SELECT MAX(RowNumber) + 1 FROM CTE_VLFs WHERE Status = 2)),0) AS int))
									
									SET @LogShrinkableSize = @LogShrinkableSize - @NextFreeVLFSize
								END
						
							-- If database in simple shrink completely is possible
							IF @RecoveryModel = 'SIMPLE'
								SET @LogShrinkableSize = @CurrentLogSizeMb
					
							-- If @TargetLogSizeMb less than @TargetMinLogSizeMb
							IF @TargetLogSizeMb < @TargetMinLogSizeMb
								SET @TargetLogSizeMb = @TargetMinLogSizeMb
							
							-- Is @TargetLogSizeMb below possible shrink area?
							IF @TargetLogSizeMb <= (@CurrentLogSizeMb - @LogShrinkableSize)
								BEGIN
									-- Get new TargetLogSizeMb according to what is shrinkble
									SET @AdjustedTargetLogSizeMb = @CurrentLogSizeMb - @LogShrinkableSize + 1
									-- Adjust @TargetAutogrowth due to new TargetLogSizeMb
									SET @TargetAutogrowth = CASE 
																WHEN @AdjustedTargetLogSizeMb <= @LogSizeLevel1 THEN @AutoGrowthLow
																WHEN @AdjustedTargetLogSizeMb > @LogSizeLevel1 AND @AdjustedTargetLogSizeMb <= @LogSizeLevel2 THEN @AutoGrowthMedium
																WHEN @AdjustedTargetLogSizeMb > @LogSizeLevel2 THEN @AutoGrowthHigh
															END
								END
							-- Is @TargetLogSizeMb below @CurrentLogSizeMb and abowe possible shrink area?
							ELSE IF @TargetLogSizeMb < @CurrentLogSizeMb AND @TargetLogSizeMb > (@CurrentLogSizeMb - @LogShrinkableSize)
								BEGIN
									-- Adjust @TargetAutogrowth due to @TargetLogSizeMb
									SET @TargetAutogrowth = CASE 
																WHEN @TargetLogSizeMb <= @LogSizeLevel1 THEN @AutoGrowthLow
																WHEN @TargetLogSizeMb > @LogSizeLevel1 AND @TargetLogSizeMb <= @LogSizeLevel2 THEN @AutoGrowthMedium
																WHEN @TargetLogSizeMb > @LogSizeLevel2 THEN @AutoGrowthHigh
															END
								END
							-- @TargetLogSizeMb is abowe @CurrentLogSizeMb!
							ELSE
								BEGIN
									-- Get new TargetLogSizeMb, set new size according to @CurrentLogSizeMb
									SET @TargetLogSizeMb = @CurrentLogSizeMb
									-- Adjust @TargetAutogrowth due to @CurrentLogSizeMb
									SET @TargetAutogrowth = CASE 
																WHEN @CurrentLogSizeMb <= @LogSizeLevel1 THEN @AutoGrowthLow
																WHEN @CurrentLogSizeMb > @LogSizeLevel1 AND @CurrentLogSizeMb <= @LogSizeLevel2 THEN @AutoGrowthMedium
																WHEN @CurrentLogSizeMb > @LogSizeLevel2 THEN @AutoGrowthHigh
															END
								END
						
							------------------- *** POPULATE SECTION START *** -------------------
							-- Populate output parameters with log file information
							IF UPPER(@Action) IN ('REPORT_OUTPUT')
								BEGIN
									SELECT @Database_id_out = @Database_id
									SELECT @DatabaseName_out = @DatabaseName
									SELECT @RecoveryModel_out = @RecoveryModel
									SELECT @LogFileName_out = @LogFileName + 'New'
									SELECT @CurrentLogSizeMb_out = @CurrentLogSizeMb
									SELECT @TargetLogSizeMb_out = @TargetLogSizeMb
									SELECT @CurrentAutoGrowth_out = @CurrentAutoGrowth 
									SELECT @CurrentAutoGrowthEnabled_out = @CurrentAutoGrowthEnabled
									SELECT @CurrentGrowthType_out = @CurrentGrowthType
									SELECT @CurrentNumberOfVLFs_out = @CurrentNumberOfVLFs
									SELECT @CurrentAvgVLFs_out = @CurrentAvgVLFs
									SELECT @CurrentMaxVLFs_out = @CurrentMaxVLFs
									SELECT @LogSizeFileId_out = @LogSizeFileId
								END	
														
							-- Populate temporay table with log file information
							INSERT INTO @LogFileOverviewTable ([Database_id], [Database], [Object], [Current Value]) SELECT @Database_id, @DatabaseName, 'Create date', CONVERT(varchar(16), @create_date, 20)
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id,'Recovery Model', @RecoveryModel
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Total data files size [MB]', @TotalDataFilesSizeMb
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Max Log backup size last ' + CAST(@BackupHistoryDays as varchar(256)) + ' days [MB]', ISNULL(CAST(@MaxLogBackupSizeMb AS varchar(256)),'')
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Log file [' + CAST(@LogFileNr AS varchar(256)) + '/' + CAST(@NoOfLogFiles AS varchar(256)) + ']', @LogFileName
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value], [Adjusted Target Value]) SELECT @Database_id, 'Log size [MB]', @CurrentLogSizeMb, @TargetLogSizeMb, ISNULL(CAST(@AdjustedTargetLogSizeMb AS varchar(256)),'')
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Log File org. created size [MB]', @LogFileOrgCreateSize
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Log used [MB]', @CurrentLogUsedMb
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Log min shrinkable size [MB]', @CurrentLogSizeMb - @LogShrinkableSize
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Auto growth enabled', @CurrentAutoGrowthEnabled
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value]) SELECT @Database_id, 'Auto growth', @CurrentAutoGrowth, @TargetAutogrowth
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value]) SELECT @Database_id, 'Growth type',@CurrentGrowthType, @TargetGrowthType
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value]) SELECT @Database_id, 'Number of VLFs', @CurrentNumberOfVLFs, @MaxNumberOfVLFs
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value]) SELECT @Database_id, 'Avg VLF size [MB]',	@CurrentAvgVLFs
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value]) SELECT @Database_id, 'Max VLF size [MB]',@CurrentMaxVLFs, @MaxVLFsizeMb
							
							-- Insert blank row
							INSERT INTO @LogFileOverviewTable ([Database_id], [Object], [Current Value], [Target Value], [Adjusted Target Value]) SELECT @Database_id, '', '', '', ''

							-- Apply rules for action
							UPDATE @LogFileOverviewTable SET [Action] = 'Y'
							WHERE ([Object] = 'Log size [MB]' AND ([Current Value] > [Target Value] AND [Current Value] > CAST([Adjusted Target Value] AS Int))) OR
								  ([Object] = 'Auto growth' AND [Current Value] <> [Target Value]) OR
								  ([Object] = 'Growth type' AND [Current Value] <> [Target Value]) OR
								  ([Object] = 'Number of VLFs' AND [Current Value] > [Target Value]) OR
								  ([Object] = 'Max VLF size [MB]' AND [Current Value] > [Target Value]) 

							------------------- *** SIMULATE, FIX SECTION START *** -------------------		
							IF UPPER(@Action) IN ('SIMULATE','FIX')  
								BEGIN
									IF (@CurrentLogSizeMb > @TargetLogSizeMb AND @CurrentLogSizeMb > CAST(ISNULL(@AdjustedTargetLogSizeMb, 0) AS int)) OR 
										(@CurrentNumberOfVLFs > @MaxNumberOfVLFs AND @CurrentLogSizeMb <= @TargetLogSizeMb)
										BEGIN
											-- Change @TargetLogSizeMb value
											IF @AdjustedTargetLogSizeMb > @TargetLogSizeMb
														SET @TargetLogSizeMb = @AdjustedTargetLogSizeMb
												
											-- Reduce the Transaction Log to its minimum size			
											SET @Sql = 'USE ' + QUOTENAME(@TargetDatabase) + '; CHECKPOINT; DBCC SHRINKFILE(' + QUOTENAME(@LogFileName) + ', 1) WITH NO_INFOMSGS; CHECKPOINT'      
											SET @NoCommandsGenerated = @NoCommandsGenerated + 1
											IF UPPER(@Action) = 'SIMULATE'
  												PRINT @Sql
											ELSE
												BEGIN
													EXEC(@Sql)
      												IF @@ERROR <> 0
														BEGIN
															SET @message = 'Error shrinking Transaction Log.'
															RAISERROR(@message, 11, 3)
															RETURN
														END 
													ELSE
														PRINT @Sql + ' --> Command successfully executed.'
												END  
											
												-- Caculate the optimal growth (an constant value as close as possible to the defined threshold)
												IF FLOOR(@TargetLogSizeMb / @MaxReallocationIncrementSizeMb) > 1
													SELECT @Step = @MaxReallocationIncrementSizeMb, @Loop = CEILING(@TargetLogSizeMb / @MaxReallocationIncrementSizeMb), @LogFileBuildSize = @Step
												ELSE
													BEGIN
														SET @LogFileBuildSize = @TargetLogSizeMb
														SET @Loop = 1
													END
											
												WHILE @Loop > 0
													BEGIN
														-- Protect against the 4096 BUG
														IF @LogFileBuildSize = 4096
															SET @LogFileBuildSize = 4000
														SET @Sql = 'USE ' + QUOTENAME(@TargetDatabase) + '; ALTER DATABASE ' + QUOTENAME(@TargetDatabase) + ' MODIFY FILE (NAME = ''' + @LogFileName + ''', SIZE = ' + CAST(@LogFileBuildSize as varchar(20))+'MB)'
														SET @NoCommandsGenerated = @NoCommandsGenerated + 1
														IF @Growth = '0'
															SET @Sql = '/* (Auto growth not enabled on file) ' + @sql + ' */'
														IF UPPER(@Action) = 'SIMULATE'
															PRINT @Sql
														ELSE
															BEGIN
																EXEC(@Sql) 
																IF @@ERROR <> 0
																	BEGIN
																		SET @message = 'Error expanding Transaction Log with ' + CAST(@LogFileBuildSize as varchar(20)) + 'MB'
																		RAISERROR(@message, 11, 5)
																		RETURN
																	END 
																ELSE
																	PRINT @Sql + ' --> Command successfully executed.'
															END
							  	         
  														IF  @TargetLogSizeMb - @LogFileBuildSize < @MaxReallocationIncrementSizeMb
  															SELECT @LogFileBuildSize = @TargetLogSizeMb, @Loop = @Loop - 1
  														ELSE
															SELECT @LogFileBuildSize = @LogFileBuildSize + @Step, @Loop = @Loop - 1
													END  
										END
							
									IF @CurrentAutoGrowth <> @TargetAutogrowth OR 
									   @CurrentGrowthType <> @TargetGrowthType
										BEGIN
											-- Calculate autogrowth setting
											SET @Sql = 'USE ' + QUOTENAME(@TargetDatabase) + '; ALTER DATABASE ' + QUOTENAME(@TargetDatabase) + ' MODIFY FILE (NAME = ''' + @LogFileName + ''', FILEGROWTH = ' + CAST(@TargetAutogrowth as varchar(20))+ @TargetGrowthType+')'      
											SET @NoCommandsGenerated = @NoCommandsGenerated + 1
											IF @Growth = '0'
												SET @Sql = '/* (Auto growth not enabled on file) ' + @sql + ' */'

											IF UPPER(@Action) = 'SIMULATE'
												PRINT @Sql
											ELSE
												BEGIN
													EXEC(@Sql)
													IF @@ERROR <> 0
														BEGIN
															SET @message = 'Error configure autogrow on Transaction Log.'
															RAISERROR(@message, 11, 3)
															RETURN
														END 
													ELSE
														PRINT @Sql + ' --> Command successfully executed.'
												END
										END
										
									-- Get new values after changes by calling sp_FixVirtualLogFiles again with @Action = Report_output
									IF UPPER(@Action) = 'FIX'
										BEGIN
											EXEC sp_FixVirtualLogFiles
													@Databases = @DatabaseName ,
													@Action = 'report_output',
													@TargetMinLogSizeMb = @TargetMinLogSizeMb,
													@TargetGrowthType = @TargetGrowthType,
													@MaxReallocationIncrementSizeMb = @MaxReallocationIncrementSizeMb,
													@MaxNumberOfVLFs = 	@MaxNumberOfVLFs,
													@MaxVLFsizeMb = @MaxVLFsizeMb,
													@BackupHistoryDays = @BackupHistoryDays,
													@DatabaseHasToExistDays = @DatabaseHasToExistDays,
													@LogSizeLevel1 = @LogSizeLevel1,
													@LogSizeLevel2 = @LogSizeLevel2,
													@AutoGrowthLow = @AutoGrowthLow,
													@AutoGrowthMedium = @AutoGrowthMedium,
													@AutoGrowthHigh = @AutoGrowthHigh,
													@Database_id_out = @Database_id output,
													@DatabaseName_out = @DatabaseName output,
													@RecoveryModel_out = @RecoveryModel output,
													@LogFileName_out = @LogFileName output,
													@CurrentLogSizeMb_out = @CurrentLogSizeMb output,
													@TargetLogSizeMb_out = @TargetLogSizeMb output,
													@CurrentAutoGrowth_out = @CurrentAutoGrowth output,
													@CurrentAutoGrowthEnabled_out = @CurrentAutoGrowthEnabled output,
													@CurrentGrowthType_out = @CurrentGrowthType output,
													@CurrentNumberOfVLFs_out = @CurrentNumberOfVLFs output,
													@CurrentAvgVLFs_out = @CurrentAvgVLFs output,
													@CurrentMaxVLFs_out = @CurrentMaxVLFs output,
													@LogSizeFileId_out = @LogSizeFileId output
												
											UPDATE @LogFileOverviewTable SET [New Value] =  @RecoveryModel WHERE [Object] = 'Recovery Model' 
											UPDATE @LogFileOverviewTable SET [New Value] =  @TotalDataFilesSizeMb WHERE ([Database_id] = @Database_id AND [Object]  = 'Total data files size [MB]') 
											UPDATE @LogFileOverviewTable SET [New Value] =  @LogFileName WHERE ([Database_id] = @Database_id AND [Object] = 'Log file [' + CAST(@LogFileNr AS varchar(256)) + '/' + CAST(@NoOfLogFiles AS varchar(256)) + ']')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentLogSizeMb WHERE ([Database_id] = @Database_id AND [Object] = 'Log size [MB]')
											UPDATE @LogFileOverviewTable SET [New Value] =  @LogFileOrgCreateSize WHERE ([Database_id] = @Database_id AND [Object] = 'Log File org. created size [MB]')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentLogUsedMb WHERE ([Database_id] = @Database_id AND [Object] = 'Log used [MB]')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentLogSizeMb - @LogShrinkableSize WHERE ([Database_id] = @Database_id AND [Object] = 'Log min shrinkable size [MB]')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentAutoGrowthEnabled WHERE ([Database_id] = @Database_id AND [Object] = 'Auto growth enabled')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentAutoGrowth WHERE ([Database_id] = @Database_id AND [Object] = 'Auto growth')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentGrowthType WHERE ([Database_id] = @Database_id AND [Object] = 'Growth type')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentNumberOfVLFs WHERE ([Database_id] = @Database_id AND [Object] = 'Number of VLFs')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentAvgVLFs WHERE ([Database_id] = @Database_id AND [Object] = 'Avg VLF size [MB]')
											UPDATE @LogFileOverviewTable SET [New Value] =  @CurrentMaxVLFs WHERE ([Database_id] = @Database_id AND [Object] = 'Max VLF size [MB]')
										END
								END	
							FETCH NEXT FROM cursor_LogFiles INTO 
									@Database_id,
									@DatabaseName, 
									@RecoveryModel,
									@LogFileName, 
									@CurrentLogSizeMb,
									@TargetLogSizeMb,
									@CurrentAutoGrowth, 
									@CurrentAutoGrowthEnabled, 
									@CurrentGrowthType, 
									@CurrentNumberOfVLFs, 
									@CurrentAvgVLFs, 
									@CurrentMaxVLFs,
									@LogSizeFileId
						END		
						CLOSE cursor_LogFiles
						DEALLOCATE cursor_LogFiles
						
				END
			ELSE
				BEGIN
					SET @message = 'Database ' + @TargetDatabase + ' is not accessible'
					IF UPPER(@Action) IN ('SCAN', 'REPORT')
						SELECT @message AS 'Action failed'
					ELSE
						PRINT '--> ' + @message
				END  
					
			FETCH NEXT FROM cursor_Databases INTO @TargetDatabase, @create_date
		END
		CLOSE cursor_Databases
		DEALLOCATE cursor_Databases  
		
		IF UPPER(@Action) IN ('SIMULATE', 'FIX') AND @NoCommandsGenerated = 0
		 	PRINT 'Database:' + QUOTENAME(@DatabaseName) + ', Log:' + QUOTENAME(@LogFileName) + ' --> No commands generated.'
		
		-- View log file information
		IF UPPER(@Action) IN ('REPORT', 'SCAN', 'FIX')
			BEGIN
				IF UPPER(@Action) = 'REPORT' 
					SELECT CASE 
								WHEN [Database] IS NULL 
								THEN '' 
								ELSE [Database] 
							END AS 'Database', 
							[Object], 
							[Current Value] 
					FROM @LogFileOverviewTable 
				ELSE IF UPPER(@Action) = 'SCAN' AND EXISTS (SELECT [Database_id] FROM @LogFileOverviewTable WHERE [Action] = 'Y')  
					SELECT CASE 
								WHEN [Database] IS NULL 
								THEN '' 
								ELSE [Database] 
							END AS 'Database', 
							[Object], 
							[Current Value], 
							[Target Value], 
							[Adjusted Target Value], 
							[Action] 
					FROM @LogFileOverviewTable
					WHERE [Database_id] IN (SELECT [Database_id] FROM @LogFileOverviewTable WHERE [Action] = 'Y')  
				ELSE IF UPPER(@Action) = 'FIX' AND EXISTS (SELECT [Database_id] FROM @LogFileOverviewTable WHERE [Action] = 'Y')  
					SELECT CASE 
								WHEN [Database] IS NULL 
								THEN '' 
								ELSE [Database] 
							END AS 'Database', 
							[Object], 
							[Current Value], 
							[Target Value], 
							[Adjusted Target Value], 
							[Action],
							CASE
								WHEN [Action] = 'Y'
								THEN [New Value]
								ELSE ''
							END AS 'New Value'
					FROM @LogFileOverviewTable
					WHERE [Database_id] IN (SELECT [Database_id] FROM @LogFileOverviewTable WHERE [Action] = 'Y')  
							
				ELSE
					PRINT 'Database:' + QUOTENAME(@DatabaseName) + ', Log:' + QUOTENAME(@LogFileName) + ' --> All OK.'   
			END
END

GO

