SET NOCOUNT ON

CREATE TABLE #DatabaseFiles
([database_name] [nvarchar](100) NOT NULL,
[fileid] [int] NOT NULL,
[type] [int] NOT NULL,
[name] [nvarchar](500) NOT NULL
) 

DECLARE @ssql nvarchar(4000)
SET @ssql= '
        IF ''?'' NOT IN (''master'',''model'',''msdb'',''tempdb'',''VIT_GLOBAL_TOOLBOX'',''LiteSpeedLocal'')
		BEGIN
        USE [?]
        SELECT db_name(),file_id,type,name FROM sys.database_files
        END'

INSERT INTO #DatabaseFiles EXEC sp_msforeachdb @ssql

DECLARE @name NVARCHAR(500)
DECLARE @restoredb NVARCHAR(max)
DECLARE @UserDB NVARCHAR(500)
DECLARE @UserDBLog NVARCHAR(500)
DECLARE @dsmlocation NVARCHAR(500)
DECLARE @tsmobject NVARCHAR(500)
DECLARE @backuptype VARCHAR(100)
DECLARE @RecoveryOption VARCHAR(100)
DECLARE @TSMPointInTimefull VARCHAR(20)

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

DECLARE @datafiles nvarchar(1000)
DECLARE @type INT
DECLARE @fileid INT
DECLARE @dfileid int
DECLARE @tfileid int

SET @dfileid=1
SET @tfileid=1
SET @restoredb = 'EXEC master.dbo.xp_restore_database @database =N'''+@name+ ''',
@tsmconfigfile = N'''+@dsmlocation+''',
@TSMObject='''+@tsmobject+'/'+@name+'\dbbackup\'+@backuptype+''',
@tsmpointintime = '''+@TSMPointInTimefull+''',
@tsmarchive = 1,
@filenumber = 1,
@with = N''STATS = 10'',
@with = N'''+@RecoveryOption+''',
@affinity = 0,
@logging = 0,
@with = N''MOVE '


PRINT REPLICATE ('--------------------------------',4)
PRINT 'PRINT ''Starting Restore of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate()) + CHAR(13)'
PRINT'GO'

DECLARE multiple_Datafiles CURSOR FOR
SELECT name,type,fileid from #DatabaseFiles where database_name = @name Order by type
OPEN multiple_Datafiles
FETCH NEXT FROM multiple_Datafiles INTO @datafiles,@type,@fileid
WHILE(@@FETCH_STATUS = 0)
BEGIN

IF @type =0
BEGIN
IF @fileid=1
SET @restoredb=@restoredb+''''''+@datafiles+''''''+' TO '+''''''+@UserDB+@name+'.mdf'''''''+',
'+'@with = N''MOVE'+''

ELSE
SET @restoredb=@restoredb+''''''+@datafiles+''''''+' TO '+''''''+@UserDB+@name+'_'+CONVERT(VARCHAR(10),@dfileid)+'.ndf'''''''+',
'+'@with = N''MOVE'+''

SET @dfileid=@dfileid+1
END


IF @type =1
BEGIN

IF @fileid=2
SET @restoredb=@restoredb+''''''+@datafiles+''''''+' TO '+''''''+@UserDBLog+@name+'.ldf'''''''+',
'+'@with = N''MOVE'+''

ELSE
SET @restoredb=@restoredb+''''''+@datafiles+''''''+' TO '+''''''+@UserDB+@name+'_'+CONVERT(VARCHAR(10),@dfileid)+'.ldf'''''''+',
'+'@with = N''MOVE'+''

SET @tfileid=@tfileid+1
END

IF @type =4
BEGIN
SET @restoredb=@restoredb+''''''+@datafiles+''''''+' TO '+''''''+@UserDB+@name+'.'+@datafiles+''''''''+',
'+'@with = N''MOVE'+''
END


FETCH NEXT FROM multiple_Datafiles INTO @datafiles,@type,@fileid
END
CLOSE multiple_Datafiles
DEALLOCATE multiple_Datafiles

SET @restoredb = substring(@restoredb,1,len(@restoredb)-17)
PRINT (@restoredb)
PRINT 'PRINT CHAR(13)'
PRINT 'PRINT ''Restore Completed of database '+@name+ ' at '' + CONVERT(VARCHAR(100),getdate())'
PRINT 'PRINT REPLICATE (''********************************'',4)'
PRINT'GO'


FETCH NEXT FROM restore_cursor INTO @name   
END   

CLOSE restore_cursor   
DEALLOCATE restore_cursor

DROP TABLE  #DatabaseFiles