USE [master]
GO
/****** Object:  StoredProcedure [dbo].[GetFileSpaceStats]    Script Date: 05/07/2013 15:41:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[GetFileSpaceStats] (@RunLocal bit = 0)
AS
BEGIN 

SET NOCOUNT ON

DECLARE @dbName sysname 

IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE name LIKE '#FileSpaceStats%') 
BEGIN
	DROP TABLE #FileSpaceStats 
END
 
CREATE TABLE #FileSpaceStats
(
	RowID int IDENTITY PRIMARY KEY, 
	Server_Name sysname NOT NULL, 
	dbName sysname NOT NULL, 
	FileType sysname NULL, 
	Total_SpaceMB decimal(20, 2) NULL, 
	UsedSpaceMB decimal(20, 2) NULL, 
	FreeSpaceMB decimal(20, 2) NULL, 
	FreePct decimal(20, 3) NULL,
	Report_Date datetime default getdate()
)
 
 
IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE name LIKE '#DataFileStats%') 
BEGIN
	DROP TABLE #DataFileStats 
END
 
CREATE TABLE #DataFileStats 
( 
	RowID int IDENTITY PRIMARY KEY,
	Fileid tinyint,
	FileGroup tinyint, 
	TotalExtents dec (20, 1), 
	UsedExtents dec (20, 1),
	Name varchar(250), 
	FileName sysname 
) 
 
IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE name LIKE '#LogSpaceStats%') 
BEGIN
	DROP TABLE #LogSpaceStats 
END
CREATE TABLE #LogSpaceStats 
( 
	RowID int IDENTITY PRIMARY KEY,
	dbName sysname, 
	TotalLogSpace dec (20, 2), 
	UsedLogSpacePct dec (20, 3), 
	Status char(1) 
) 
 
DECLARE @string sysname 
DECLARE cur_dbName CURSOR FOR 
 
SELECT name 
FROM master..sysdatabases WHERE dbid > 4
 
OPEN cur_dbName 
 
FETCH NEXT FROM cur_dbName into @dbName 
WHILE @@FETCH_Status=0 
BEGIN 
 
	DELETE #DataFileStats
 
	SET @string = 'USE [' + @dbName + '] DBCC SHOWFILESTATS WITH NO_INFOMSGS' 
 
	INSERT INTO #DataFileStats 
	EXEC (@string) 
 
	INSERT #FileSpaceStats(Server_Name, dbName, FileType, Total_SpaceMB,UsedSpaceMB, FreeSpaceMB, FreePct)
 
	SELECT @@SERVERNAME, @dbName,'DATA', (SUM(TotalExtents)*64/1024), 
			(SUM(UsedExtents)*64/1024), ((SUM(TotalExtents)*64/1024)-(SUM(UsedExtents)*64/1024)),
			(((SUM(TotalExtents)*64/1024)-(SUM(UsedExtents)*64/1024))*100/(SUM(TotalExtents)*64/1024))
	FROM #DataFileStats 
 
FETCH NEXT FROM cur_dbName into @dbName 
END 
CLOSE cur_dbName 
DEALLOCATE cur_dbName 
 
 
 
INSERT #LogSpaceStats
EXEC ('DBCC sqlperf(logspace) WITH NO_INFOMSGS') 
 
INSERT #FileSpaceStats (Server_Name, dbName, FileType, Total_SpaceMB, 
					UsedSpaceMB, FreeSpaceMB, FreePct)
SELECT @@SERVERNAME, dbName, 'LOG', TotalLogSpace, (TotalLogSpace*(UsedLogSpacePct/100)),
	 (TotalLogSpace-(TotalLogSpace*(UsedLogSpacePct/100))), (100-UsedLogSpacePct)
FROM #LogSpaceStats WHERE dbName NOT IN('master','msdb','model','tempdb')

IF @RunLocal = 1
BEGIN
  SELECT * FROM #FileSpaceStats
END
ELSE
BEGIN	
		DECLARE @Loop int,
		@Subject varchar(100),
		@Body varchar(4000)
 
		SELECT @Subject = 'SQL Monitor Alert: ' + @@servername
 
		SELECT @Loop = min(RowID)FROM #FileSpaceStats WHERE FreePct <= 30
 
		WHILE @Loop IS NOT NULL
		BEGIN
			
			DECLARE @FileType varchar(10),
			@TotalSpace decimal(20,2)
			SELECT @FileType = FileType,@TotalSpace= Total_SpaceMB FROM #FileSpaceStats WHERE RowID=@Loop
			
			IF @FileType='DATA'
			BEGIN
			
			SELECT 	@Body =  convert(char(15),'Database:') + isnull(dbName, 'Unknown') + char(13) +
			convert(char(15),'FileType:') + isnull(FileType, 'Unknown') + char(10) +
			convert(char(15),'Total_SpaceMB:') + convert(varchar,Total_SpaceMB) + 'MB'+char(13) +
			convert(char(25),'Free Space Remaining:') + convert(varchar, FreePct) + '%'+ char(13) +
			convert(char(15),'EventTime:') + convert(varchar, getdate())+CHAR(13)++CHAR(13)+'Kindly contact BEKAERT DATABASE SUPPORT TEAM.'+CHAR(13)
			FROM #FileSpaceStats
			WHERE RowID = @Loop
 
			EXEC [dbo].[SendEmailNotification] @Subject,@Body
			END
			
			IF @FileType='LOG'AND @TotalSpace > 1048576
			BEGIN
			
			SELECT 	@Body =  convert(char(15),'Database:') + isnull(dbName, 'Unknown') + char(13) +
			convert(char(15),'FileType:') + isnull(FileType, 'Unknown') + char(10) +
			convert(char(15),'Total_SpaceMB:') + convert(varchar,Total_SpaceMB) + 'MB'+char(13) +
			convert(char(25),'Free Space Remaining:') + convert(varchar, FreePct) + '%'+ char(13) +
			convert(char(15),'EventTime:') + convert(varchar, getdate())+CHAR(13)++CHAR(13)+'Kindly contact BEKAERT DATABASE SUPPORT TEAM.'+CHAR(13)
			FROM #FileSpaceStats
			WHERE RowID = @Loop
			
			EXEC [dbo].[SendEmailNotification] @Subject,@Body
			END

			SELECT @Loop = min(RowID)
			FROM #FileSpaceStats
			WHERE FreePct <= 30
			AND RowID > @Loop
 
		END
		
END
 
 
DROP TABLE #FileSpaceStats
DROP TABLE #DataFileStats 
DROP TABLE #LogSpaceStats

END