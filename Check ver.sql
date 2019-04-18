DECLARE @ver nvarchar(128)
SET @ver = CAST(serverproperty('ProductVersion') AS nvarchar)
--SET @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)


IF ( @ver like  '8.%' )
   SELECT 'SQL Server 2000' as [SQL Server],serverproperty('Productlevel') as [Current Patch],'SP4' as [Latest Patch]
ELSE IF ( @ver like '9.%' )
   SELECT 'SQL Server 2005' as [SQL Server],serverproperty('Productlevel') as [Current Patch],'SP4' as [Latest Patch]
ELSE IF ( @ver like '10.0.%' )
   SELECT 'SQL Server 2008' as [SQL Server],serverproperty('Productlevel') as [Current Patch],'SP4' as [Latest Patch]
ELSE IF ( @ver like '10.50.%' )
   SELECT 'SQL Server 2008 R2' as [SQL Server],serverproperty('Productlevel') as [Current Patch],'SP3' as [Latest Patch]
ELSE IF ( @ver like '11%' )
   SELECT 'SQL Server 2012' as [SQL Server],serverproperty('Productlevel') as [Current Patch],'SP2' as [Latest Patch]
ELSE
   SELECT 'Unsupported SQL Server Version'