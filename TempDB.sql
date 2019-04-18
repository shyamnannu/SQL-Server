-- Tempdb concurrency enhancement
set nocount on;
use tempdb;
declare @total_temp_db_data_size_in_mb int;
declare @temp_db_log_size_in_mb int;
set @total_temp_db_data_size_in_mb = 51200;
set @temp_db_log_size_in_mb = 20480;
declare @err int;
declare @cmd nvarchar(4000);
declare @number_of_cores int;
declare @tempdb_file_size_in_mb int;
declare @tempdb_file_size_in_blocks int;
declare @tempdb_path nvarchar(4000);
declare @number_of_tempdb_data_files int;
-- Find number of processor cores on system
declare @SVer table (ID int, Name sysname, Internal_Value int,
Value nvarchar(512))
insert @SVer exec master.dbo.xp_msver ProcessorCount
select @number_of_cores = Internal_Value from @SVer where Name =
N'ProcessorCount';
set @number_of_tempdb_data_files = @number_of_cores;
if @number_of_tempdb_data_files > 8 set @number_of_tempdb_data_files
= 8;
set @tempdb_file_size_in_mb = @total_temp_db_data_size_in_mb /
@number_of_tempdb_data_files;
set @tempdb_file_size_in_blocks = @tempdb_file_size_in_mb * 128;
select @tempdb_path = substring(physical_name, 0,
patindex('%\tempdb.mdf', physical_name) + 1) from
tempdb.sys.database_files where name = 'tempdev';
set @cmd = 'use tempdb;¤DBCC FREESYSTEMCACHE (''ALL'');¤DBCC
FREEPROCCACHE;¤';
set @cmd = @cmd + 'alter database tempdb add log file (name =
''templog2'', filename = ''' + @tempdb_path + 'templog2.ldf'', size =
1, filegrowth = 10%);¤';
set @cmd = @cmd + 'dbcc shrinkfile(templog, 1);¤';
set @cmd = @cmd + 'alter database tempdb modify file (name =
''templog'', size = ' + cast(@temp_db_log_size_in_mb as nvarchar(16))
+ ', filegrowth = 63 MB);¤';
set @cmd = @cmd + 'alter database tempdb remove file templog2;¤';
-- A secondary transaction log file is created
-- so that the primary transaction log file can always be shrunk.
declare @file_id int;
declare @file_name sysname;
declare @size int;
declare tempdb_file_cursor cursor for
select file_id, name, size from tempdb.sys.database_files where
type_desc = 'ROWS' order by file_id desc;
open tempdb_file_cursor
while 1 = 1
begin
fetch from tempdb_file_cursor into @file_id, @file_name, @size
select @err = @@error if @err <> 0 break;
if @@fetch_status <> 0 break;
if @file_id = 1
begin
if @size > @tempdb_file_size_in_blocks
begin
set @cmd = @cmd + 'dbcc shrinkfile(' + cast(@file_id
as nvarchar(4)) + ', 1);¤';
set @cmd = @cmd + 'alter database tempdb modify file
(name = ''' + @file_name + ''', size = ' +
cast(@tempdb_file_size_in_mb as nvarchar(16)) + ');¤';
end
else if @tempdb_file_size_in_blocks > @size
begin
set @cmd = @cmd + 'alter database tempdb modify file
(name = ''' + @file_name + ''', size = ' +
cast(@tempdb_file_size_in_mb as nvarchar(16)) + ');¤';
end
set @cmd = @cmd + 'alter database tempdb modify file (name
= ''' + @file_name + ''', filegrowth = 100 MB);¤';
end
else
begin
set @cmd = @cmd + 'DBCC FREESYSTEMCACHE (''ALL'');DBCC
FREEPROCCACHE;dbcc shrinkfile(' + cast(@file_id as nvarchar(4)) + ',
EMPTYFILE);¤';
set @cmd = @cmd + 'alter database tempdb remove file ' +
@file_name + ';¤';
end
end
deallocate tempdb_file_cursor;
-- Add new tempdb files
declare @i int;
set @i = 1;
while @i < @number_of_tempdb_data_files
begin
set @i = @i + 1;
set @cmd = @cmd + 'alter database tempdb add file (name =
''tempdev' + cast(@i as nvarchar(4)) + ''', filename = ''' +
@tempdb_path + 'tempdb' + cast(@i as nvarchar(4)) + '.ndf'', size = '
+ cast(@tempdb_file_size_in_mb as nvarchar(16)) + ', filegrowth = 100
MB);¤'
end
set @cmd = replace(@cmd, '¤', char(13) + char(10));
exec (@cmd)