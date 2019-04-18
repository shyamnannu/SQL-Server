set nocount on;
exec sp_configure 'show advanced option', '1';
go
reconfigure;
go
declare @max_server_memory varchar(10);
declare @number_of_cores int;
set @max_server_memory = '3200';
-- Find number of processor cores on system
declare @SVer table (ID int, Name sysname, Internal_Value int,
Value nvarchar(512))
insert @SVer exec master.dbo.xp_msver ProcessorCount
select @number_of_cores = Internal_Value from @SVer where Name =
N'ProcessorCount';
print 'Number of cores found: ' + cast(@number_of_cores as
nvarchar(16)) + '.';
exec sp_configure 'min server memory', '0';
exec sp_configure 'max server memory', @max_server_memory;
exec sp_configure 'Ole Automation Procedures', '1';
exec sp_configure 'xp_cmdshell', '1';
exec sp_configure 'remote admin connections', '1';
exec sp_configure 'optimize for ad hoc workloads', '1';
-- Set max degree of parallelism
declare @max_dop int;
declare @numa_nodes int;
select @numa_nodes = count(distinct memory_node_id) from
sys.dm_os_memory_clerks where memory_node_id <> 64
if @numa_nodes > 1
begin
set @max_dop = @number_of_cores / @numa_nodes;
end
else
begin
set @max_dop = @number_of_cores * 4 / 5;
end
if @max_dop > 8 set @max_dop = 8;
exec sp_configure 'max degree of parallelism', @max_dop;
go
reconfigure with override;
go
-- Set Login audit to audit failed logins.
exec xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel',
REG_DWORD, 2
-- Set model database properties
alter database model set auto_shrink off, auto_close off;
go
-- Increase the maximum number of error log files to 20.
exec xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs',
REG_DWORD, 20