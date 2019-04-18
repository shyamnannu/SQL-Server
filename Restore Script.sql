/*************************************************************
Script made by : Lester A. Policarpio
Email Address : lpolicarpio2001@yahoo.com
Date Created : September 03, 2007
--=UPDATES=--

January 17, 2008
- Solved outputed value of the @restoredb variable
- Solved the "invalid length parameter" issue

May 6, 2008
- Removed unused variables
- Add the headeronly command to accept non sql backup format 
 (dbname_db_YYYYMMDDHHMM.BAK)
- Add more comments

May 12, 2008
- Accept Backup Files With Multiple NDFs

May 23, 2008
- Solved the problem when RESTORE HEADERONLY produces more than 1 value

--=LIMITATIONS=--
- This script is tested for backup files ".BAK" only 
-- SCRIPT NEEDS TO BE ALTERED IF BACKUP EXTENSION IS NOT ".BAK"
*************************************************************/
SET NOCOUNT ON
--Drop Tables if it exists in the database
if exists (select name from sysobjects where name = 'migration_lester')
DROP TABLE migration_lester
if exists (select name from sysobjects where name = 'header_lester')
DROP TABLE header_lester
if exists (select name from sysobjects where name = 'cmdshell_lester')
DROP TABLE cmdshell_lester

--Create Tables 
--(cmdshell_lester table for the cmdshell command)
--(migration_lester table for the restore filelistonly command)
--(header_lester table for the restore headeronly command)
CREATE TABLE cmdshell_lester( fentry varchar(1000))

CREATE TABLE migration_lester(LogicalName varchar(1024),
PhysicalName varchar(4000),type char(1),FileGroupName varchar(50),
size real,MaxSize real)

CREATE TABLE header_lester (BackupName varchar(50),
BackupDescription varchar(100),BackupType int,
ExpirationDate nvarchar(50),Compressed int,Position int,
DeviceType int,UserName varchar(30),ServerName varchar(30),
DatabaseName varchar(50),DatabaseVersion int,
DatabaseCreationDate datetime,BackupSize bigint,FirstLsn binary,
LastLsn binary,CheckpointLsn binary,DifferentialBasLsn binary,
BackupStartDate datetime,BackupFinishDate datetime,SortOrder int,
CodePage int,UnicodeLocaleid int,UnicodeComparisonStyle int,
CompatibilityLevel int,SoftwareVendorId int,SoftwareVersionMajor int,
SoftwareVersionMinor int,SoftwareVersionBuild int,
MachineName varchar(50),Flags int,BindingId nvarchar(50),
RecoveryForkId nvarchar(50),Collation nvarchar(50))

--Declare Variables
DECLARE @path varchar(1024),@restore varchar(1024)
DECLARE @restoredb varchar(2000),@extension varchar(1024),@newpath_ldf varchar(1024)
DECLARE @pathension varchar(1024),@newpath_mdf varchar(1024),@header varchar(500)

--Set Values to the variables
SET @newpath_mdf = 'C:\' --new path wherein you will put the mdf
SET @newpath_ldf = 'D:\' --new path wherein you will put the ldf
SET @path = 'D:\' --Path of the Backup File
SET @extension = 'BAK'
SET @pathension = 'dir /OD '+@Path+'*.'+@Extension

--Insert the value of the command shell to the table
INSERT INTO cmdshell_lester exec master..xp_cmdshell @pathension
--Delete non backup files data, delete null values
DELETE FROM cmdshell_lester WHERE FEntry NOT LIKE '%.BAK%' 
DELETE FROM cmdshell_lester WHERE FEntry is NULL
--Create a cursor to scan all backup files needed to generate the restore script
DECLARE @migrate varchar(1024)
DECLARE migrate CURSOR FOR
select substring(FEntry,40,50) as 'FEntry'from cmdshell_lester 
OPEN migrate
FETCH NEXT FROM migrate INTO @migrate
WHILE (@@FETCH_STATUS = 0)BEGIN
--Added feature to get the dbname of the backup file
SET @header = 'RESTORE HEADERONLY FROM DISK = '+''''+@path+@Migrate+''''
INSERT INTO header_lester exec (@header)
--Get the names of the mdf and ldf
set @restore = 'RESTORE FILELISTONLY FROM DISK = '+''''+@path+@migrate+''''
INSERT INTO migration_lester EXEC (@restore)
--Update value of the table to add the new path+mdf/ldf names
UPDATE migration_lester SET physicalname = reverse(physicalname)
UPDATE migration_lester SET physicalname = 
substring(physicalname,1,charindex('\',physicalname)-1)

UPDATE migration_lester SET physicalname = @newpath_mdf+reverse(physicalname) where type = 'D'
UPDATE migration_lester SET physicalname = @newpath_ldf+reverse(physicalname) where type = 'L'
--@@@@@@@@@@@@@@@@@@@@
--Set a value to the @restoredb variable to hold the restore database script
IF (select count(*) from migration_lester) = 2
BEGIN
SET @restoredb = 'RESTORE DATABASE '+(select top 1 DatabaseName from header_lester)
+' FROM DISK = '+ ''''+@path+@migrate+''''+' WITH MOVE '+''''
+(select logicalname from migration_lester where type = 'D')+''''
+' TO '+ ''''+( select physicalname from migration_lester WHERE physicalname like '%mdf%')
+''''+', MOVE '+''''+ (select logicalname from migration_lester where type = 'L')
+''''+' TO '+''''+( select physicalname from migration_lester 
WHERE physicalname like '%ldf%')+''''
print (@restoredb) 
END

IF (select count(*) from migration_lester) > 2
BEGIN
SET @restoredb = 
'RESTORE DATABASE '+(select top 1 DatabaseName from header_lester)+
' FROM DISK = '+''''+@path+@migrate+''''+'WITH MOVE '
DECLARE @multiple varchar(1000),@physical varchar(1000)
DECLARE multiple CURSOR FOR
Select logicalname,physicalname from migration_lester
OPEN multiple
FETCH NEXT FROM multiple INTO @multiple,@physical
WHILE(@@FETCH_STATUS = 0)
BEGIN
SET @restoredb=@restoredb+''''+@multiple+''''+' TO '+''''+@physical+''''+','+'MOVE '+''
FETCH NEXT FROM multiple INTO @multiple,@physical
END
CLOSE multiple
DEALLOCATE multiple
SET @restoredb = substring(@restoredb,1,len(@restoredb)-5)
print (@restoredb)
END

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- Run print @restoredb first to view the databases to be restored
-- When ready, run exec (@restoredb)
-- EXEC (@restoredb)

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
--Clear data inside the tables to give way for the next 
--set of informations to be put in the @restoredb variable 
TRUNCATE TABLE migration_lester
TRUNCATE TABLE header_lester
FETCH NEXT FROM migrate INTO @migrate
END
CLOSE migrate
DEALLOCATE migrate
--@@@@@@@@@@@@@@@@@@@

--Drop Tables 
DROP TABLE migration_lester
DROP TABLE cmdshell_lester
DROP TABLE header_lester




