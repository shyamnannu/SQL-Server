
PRINT '***************** Server Name ********************'
SET NOCOUNT ON
select @@SERVERNAME
go


PRINT '***************** Version ********************'
SET NOCOUNT ON
select @@version
go


PRINT '***************** License Information********************'
SET NOCOUNT ON
SELECT SERVERPROPERTY ('LicenseType')
go


PRINT '***************** Number of Licenses********************'
SET NOCOUNT ON
SELECT SERVERPROPERTY ('NumLicenses')
go


PRINT '***************** Collation Information ********************'
SET NOCOUNT ON
SELECT SERVERPROPERTY ('Collation')
go


PRINT '***************** Clustered ********************'
SET NOCOUNT ON
IF (SELECT SERVERPROPERTY ('IsClustered')) = 0 
BEGIN
	PRINT 'SERVER IS NOT CLUSTERED'
END
	ELSE 
	PRINT 'SERVER IS CLUSTERED'
go


PRINT '***************** Full-text catalog ********************'
SET NOCOUNT ON
IF (SELECT SERVERPROPERTY ('IsFullTextInstalled')) = 0 
BEGIN
	PRINT 'FULL TEXT IS NOT INSTALLED'
END
	ELSE 
	PRINT 'FULL TEXT IS INSTALLED'
go


PRINT '***************** Is Full-text catalog enabled on each database??? ********************'
PRINT '***************** If 1 it is enabled and If 0 it is not enabled ********************'

SET NOCOUNT ON
EXEC sp_MSforeachdb "USE ?; PRINT '?' SELECT DATABASEPROPERTY('?', 'IsFulltextEnabled') " 
go

PRINT '***************** Authentication mode ********************'
SET NOCOUNT ON
IF (SELECT SERVERPROPERTY ('IsIntegratedSecurityOnly')) = 0 
BEGIN
	PRINT 'MIXED MODE AUTHENTICATION'
END
	ELSE 
	PRINT 'WINDOWS ONLY AUTHENTICATION'
go


PRINT '***************** xp_msver Details ********************'
SET NOCOUNT ON
exec master..xp_msver
go


PRINT '***************** Server Configuration ********************'
SET NOCOUNT ON
exec sp_configure
go


PRINT '***************** Database Information ********************'
SET NOCOUNT ON
exec sp_helpdb
go


PRINT '***************** Data and Log file location ********************'
SET NOCOUNT ON
SELECT * FROM sysaltfiles
go

PRINT '***************** Log file size information ********************'
SET NOCOUNT ON
dbcc sqlperf(logspace)
go


PRINT '***************** Login Information ********************'
SET NOCOUNT ON
exec sp_helplogins
go


PRINT '***************** Server Role Information ********************'
SET NOCOUNT ON
exec sp_helpsrvrolemember
go


PRINT '***************** SQL JOb information ********************'
SET NOCOUNT ON
exec msdb..sp_help_job
go


