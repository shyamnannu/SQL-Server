SET NOCOUNT ON

CREATE TABLE #DatabaseFiles
	([database_name] [nvarchar](100) NOT NULL,
	[fileid] [int] NOT NULL,
	[type] [int] NOT NULL,
	[name] [nvarchar](500) NOT NULL
	) 

DECLARE @ssql nvarchar(4000)
SET @ssql= '
        if ''?'' NOT IN (''master'',''model'',''msdb'',''tempdb'',''VIT_GLOBAL_TOOLBOX'',''LiteSpeedLocal'')
		BEGIN
        USE [?]
        SELECT db_name(),file_id,type,name FROM sys.database_files
        END'

INSERT INTO #DatabaseFiles EXEC sp_msforeachdb @ssql


DECLARE @name NVARCHAR(500)
DECLARE @restoredb NVARCHAR(max)
DECLARE @dsmlocation NVARCHAR(500)
DECLARE @tsmobject NVARCHAR(500)
DECLARE @backuptype VARCHAR(100)
DECLARE @RecoveryOption VARCHAR(100)
DECLARE @Primary NVARCHAR(500)
DECLARE @Transactional NVARCHAR(500)
DECLARE @TSMPointInTimefull VARCHAR(20)
DECLARE @UserDB NVARCHAR(500)
DECLARE @UserDBLog NVARCHAR(500)


SET @dsmlocation ='D:\SEGBGSDB01-SQLT_LS\dsm.opt'
SET @tsmobject = 'SEGBGSDB01-SQLTSQLT'
SET @backuptype ='FULL'
SET @RecoveryOption ='NORECOVERY'
SET @TSMPointInTimefull ='2012-10-11 11:00:00'
SET @UserDB ='W:\MSSQL10.SQL1\MSSQL\DATA\UserDB\'
SET @UserDBLog ='W:\MSSQL10.SQL1\MSSQL\DATA\UserDBLog\'

DECLARE restore_cursor CURSOR FOR  
SELECT DISTINCT  rtrim(database_name) FROM #DatabaseFiles

OPEN restore_cursor   
FETCH NEXT FROM restore_cursor INTO @name

WHILE @@FETCH_STATUS = 0   
BEGIN

IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name)= 2
BEGIN
PRINT REPLICATE ('--------------------------------',4)
PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'

SET @Primary = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=1)
SET @Transactional = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=2)
SET @restoredb = 'EXEC master.dbo.xp_restore_database @database = N'''+@name+''',
@tsmconfigfile = N'''+@dsmlocation+''',
@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
@tsmpointintime = '''+@TSMPointInTimefull+''',
@tsmarchive = 1,
@filenumber = 1,
@with = N''STATS = 10'',
@with = N'''+@RecoveryOption+''',
@with = N''MOVE '''''+@Primary+''''' TO '''''+@UserDB+ +@name+'.mdf'''''',
@with = N''MOVE '''''+@Transactional+''''' TO '''''+@UserDBLog+ +@name+'.ldf'''''',
@affinity = 0,
@logging = 0
'
PRINT (@restoredb)
PRINT 'PRINT CHAR(13)'
PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
PRINT 'PRINT REPLICATE (''********************************'',4)'
PRINT'GO'

END

IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type in(0,1) ) > 2
BEGIN

	IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type =0 ) > 1
	BEGIN
	
	DECLARE @Primary2 NVARCHAR(500)
	
	PRINT REPLICATE ('--------------------------------',4)
	PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'
	
	SET @Primary = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=1)
	SET @Primary2 = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=3)
	SET @Transactional = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=2)
	SET @restoredb = 'EXEC master.dbo.xp_restore_database @database = N'''+@name+''',
	@tsmconfigfile = N'''+@dsmlocation+''',
	@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
	@tsmpointintime = '''+@TSMPointInTimefull+''',
	@tsmarchive = 1,
	@filenumber = 1,
	@with = N''STATS = 10'',
	@with = N'''+@RecoveryOption+''',
	@with = N''MOVE '''''+@Primary+''''' TO '''''+@UserDB+ +@name+'.mdf'''''',
	@with = N''MOVE '''''+@Primary2+''''' TO '''''+@UserDB+ +@name+'_2.ndf'''''',
	@with = N''MOVE '''''+@Transactional+''''' TO '''''+@UserDBLog+ +@name+'.ldf'''''',
	@affinity = 0,
	@logging = 0
	'	'
	PRINT (@restoredb)
	PRINT 'PRINT CHAR(13)'
	PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
	PRINT 'PRINT REPLICATE (''********************************'',4)'
	PRINT'GO'
	END

	IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type =1 ) > 1
	BEGIN

	DECLARE @Transactional2 NVARCHAR(500)

	PRINT REPLICATE ('--------------------------------',4)
	PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'
	
	SET @Primary = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=1)
	SET @Transactional = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=2)
	SET @Transactional2 = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=3)
	SET @restoredb = 'EXEC master.dbo.xp_restore_database @database = N'''+@name+''',
	@tsmconfigfile = N'''+@dsmlocation+''',
	@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
	@tsmpointintime = '''+@TSMPointInTimefull+''',
	@tsmarchive = 1,
	@filenumber = 1,
	@with = N''STATS = 10'',
	@with = N'''+@RecoveryOption+''',
	@with = N''MOVE '''''+@Primary+''''' TO '''''+@UserDB+ +@name+'.mdf'''''',
	@with = N''MOVE '''''+@Transactional+''''' TO '''''+@UserDBLog+ +@name+'.ldf'''''',
	@with = N''MOVE '''''+@Transactional2+''''' TO '''''+@UserDBLog+ +@name+'_2.ldf'''''',
	@affinity = 0,
	@logging = 0
	'	'
	PRINT (@restoredb)
	PRINT 'PRINT CHAR(13)'
	PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
	PRINT 'PRINT REPLICATE (''********************************'',4)'
	PRINT'GO'
	END

END

IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type =4 ) > 0
BEGIN

	IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type =4 ) = 1
	BEGIN
	
	DECLARE @FT1 NVARCHAR(500)

	PRINT REPLICATE ('--------------------------------',4)
	PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'
	
	SET @Primary = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=1)
	SET @Transactional = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=2)
	SET @FT1 = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=65537)
	SET @restoredb = 'EXEC master.dbo.xp_restore_database @database = N'''+@name+''',
	@tsmconfigfile = N'''+@dsmlocation+''',
	@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
	@tsmpointintime = '''+@TSMPointInTimefull+''',
	@tsmarchive = 1,
	@filenumber = 1,
	@with = N''STATS = 10'',
	@with = N'''+@RecoveryOption+''',
	@with = N''MOVE '''''+@Primary+''''' TO '''''+@UserDB+ +@name+'.mdf'''''',
	@with = N''MOVE '''''+@Transactional+''''' TO '''''+@UserDBLog+ +@name+'.ldf'''''',
	@with = N''MOVE '''''+@FT1+''''' TO '''''+@UserDB+ +@name+ '.' +@FT1+''''''',
	@affinity = 0,
	@logging = 0
	'
	PRINT (@restoredb)
	PRINT 'PRINT CHAR(13)'
	PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
	PRINT 'PRINT REPLICATE (''********************************'',4)'
	PRINT'GO'
	END

	IF (SELECT COUNT(1) from #DatabaseFiles where database_name = @name and type =4 ) = 2
	BEGIN
	
	DECLARE @FT2 NVARCHAR(500)
	
	PRINT REPLICATE ('--------------------------------',4)
	PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'
	SET @Primary = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=1)
	SET @Transactional = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=2)
	SET @FT1 = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=65537)
	SET @FT2 = (SELECT name FROM #DatabaseFiles WHERE database_name =@name and fileid=65538)
	SET @restoredb = 'EXEC master.dbo.xp_restore_database @database = N'''+@name+''',
	@tsmconfigfile = N'''+@dsmlocation+''',
	@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
	@tsmpointintime = '''+@TSMPointInTimefull+''',
	@tsmarchive = 1,
	@filenumber = 1,
	@with = N''STATS = 10'',
	@with = N'''+@RecoveryOption+''',
	@with = N''MOVE '''''+@Primary+''''' TO '''''+@UserDB+ +@name+'.mdf'''''',
	@with = N''MOVE '''''+@Transactional+''''' TO '''''+@UserDBLog+ +@name+'.ldf'''''',
	@with = N''MOVE '''''+@FT1+''''' TO '''''+@UserDB+ +@name+ '.' +@FT1+''''''',
	@with = N''MOVE '''''+@FT2+''''' TO '''''+@UserDB+ +@name+ '.' +@FT2+''''''',
	@affinity = 0,
	@logging = 0
	'
	PRINT (@restoredb)
	PRINT 'PRINT CHAR(13)'
	PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
	PRINT 'PRINT REPLICATE (''********************************'',4)'
	PRINT'GO'
	END

END

FETCH NEXT FROM restore_cursor INTO @name   
END   

CLOSE restore_cursor   
DEALLOCATE restore_cursor

DROP TABLE  #DatabaseFiles



