/* 
	V1.0	??			GLB WINDOWS SQL 2ND
	V1.1	2011-03-08	Sebastien Lapoujade (GLB SQL 3rd)	Creation
	V1.2	2011-04-08	Sebastien Lapoujade (GLB SQL 3rd)	Changes on maxdop setting
	V1.3	2011-05-15	Sebastien Lapoujade (GLB SQL 3rd)	Compatibility Level taken into account (linked server to SEGOTN10232)
	
	This script can be used to set below mentioned databases properties for all databases in a Instance.
	Resource database is excluded
	System databases are only checked for Autoclose / Autoshrink
	If possible, settings are only changed if they have the default value
	
	Potential Problems:
	-FILEGROWTH cannot be greater than MAXSIZE (if <60MB)
	-segotn10232 cannot be contacted by servers "outside" vcn.
*/

set nocount on

Declare
	@InstanceVersion			varchar(15), 
	@MajorVersion				varchar(3),
	@ServerName					sysname,
	@MachineName				sysname,
	@InstanceName				sysname,
	@DBname						sysname,
	@FName 						varchar(500),
	@FileType 					varchar(5),
	@AutogrowthSize  			smallint,
	@AutogrowthType 			varchar(6),
	@SuggestedGrowthSize		varchar(10),
	@InitialSize				varchar(6),
	@CmdFiles					Nvarchar(1000),
	@Is_Auto_Close_On			bit,
	@Is_Auto_Shrink_On			bit,
	@Page_Verify_option_Desc	nvarchar(60),
	@compatibility_level		varchar(6),
	@SuggestedCompLevel			varchar(6),
	@CmdCompLevel				Nvarchar(2000),
	@CmdDBOptions				Nvarchar(1000),
	@MinServerMemory			varchar(10),		--in MB
	@MaxServerMemory			varchar(10),		--in MB
	@ServerPhysicalMemoryMB		varchar(10),		--in MB
	@ServerPhysicalMemoryGB		varchar(10),		--in GB
	@ProcArchi					varchar(3),
	@NumberOfInstances			tinyint,
	@AWE_Enabled				varchar(6),
	@OLE_Automation				varchar(6),
	@XPCmdShell					varchar(6),
	@RemoteAdminConnections		varchar(6),
	@NumberOfCores				tinyint,
	@NumberOfNumaNodes			tinyint,
	@MaxDOP						varchar(6),
	@NumberOfPhysicalCPUs		tinyint

--Check instance version
set @InstanceVersion = 
(
	select convert(varchar(15),SERVERPROPERTY('ProductVersion'))
)
set @MajorVersion = left(@InstanceVersion,CHARINDEX('.',@InstanceVersion)-1)
	
if @MajorVersion in ('7','8')
	print 'The script is not valid for SQL 7 or SQL 2000'
else
begin
	 set @MachineName = convert(varchar,serverproperty('MachineName'))
	 set @InstanceName = convert(varchar,serverproperty('InstanceName')) 

	/*
		-------------------------------------------------------------
		---------------------FILES OPTIONS------------------------
		-------------------------------------------------------------
	*/
	declare @FileResult table 
	(
		InstanceName		varchar(50), 
		Dbname				varchar(500),
		Fname				varchar(500),
		FileType			varchar(5),
		AutoGrowthSize		varchar(50),
		AutoGrowthType		varchar(6),
		InitialSize			varchar(6),
		Error				nvarchar(2048),
		Treated				bit
	)
	Set @ServerName = @@servername
	insert into @FileResult
	select
		@ServerName,									--InstanceName												
		db_name(dbid) as dbname,						--dbname
		name,											--fname		
		case status & 0x40								--FileType																
			when 0x40 then 'L' 
			else 'D' 
		end,			
		case status & 0x100000							--AutoGrowthDbSize						
			when 0x100000 then growth 
			else (convert (bigint, growth) * 8/1024) 
		end,
		case status & 0x100000							--AutoGrowthLogSize
			when 0x100000 then '%' 
			else 'MB' 
		end,
		size,											--InitialSize
		'',												--error
		0												--treated
	from sys.sysaltfiles 
	where dbid <> 32767 --exclusion of resource database	
	while exists 
	(
		select 1
		from @FileResult
		where Treated <> 1
		and Fname is not NULL	--to avoid infinite loop in case there is no record
	)
	begin
		select top 1
			@DBname =			Dbname,
			@FName =			Fname,
			@FileType =			FileType,
			@AutogrowthSize = 	AutoGrowthSize,
			@AutogrowthType =	AutoGrowthType,
			@InitialSize =		InitialSize
		from @FileResult 
		where Treated <> 1
		order by Fname
		if @DBname not in ('master','msdb','tempdb')	--system databases only checked for
																--autoclose/autoshrink
		begin
			--LOG FILEGROWTH
			if RTRIM(ltrim(@FileType)) = 'L'
			begin
				if @DBname = 'model'
						set @SuggestedGrowthSize = '100'
					else	
						set @SuggestedGrowthSize = '60'
				if @AutogrowthSize <> @SuggestedGrowthSize or @AutogrowthType <> 'MB' 
				Begin Try
					Set @CmdFiles='Alter database [' + @dbname + '] modify file (name= [' + @FName + '], filegrowth='+@SuggestedGrowthSize+'MB)'
					print @CmdFiles
					Exec sp_executesql @CmdFiles
					Update @FileResult 
					Set AutoGrowthSize = 60, 
						AutoGrowthType = 'MB'
					where Fname=@FName 
				End Try 
				Begin Catch
					Update @FileResult 
					Set AutoGrowthType = '##PB##', Error = ERROR_MESSAGE() 
					where Fname = @FName
				End Catch
			end
			--DATA FILEGROWTH
			if RTRIM(ltrim(@FileType)) = 'D'
			begin
				if @DBname = 'model'
					set @SuggestedGrowthSize = '100'
				else If @AutogrowthSize / 200 < = 10
					Set @SuggestedGrowthSize = 10
				else If @AutogrowthSize / 200 > 10 and @AutogrowthSize / 200 < 50
					Set @SuggestedGrowthSize = 50
				else If @AutogrowthSize / 200 > = 50
					Set @SuggestedGrowthSize = 100
				if @AutogrowthSize <> @SuggestedGrowthSize or @AutogrowthType <> 'MB' 
				Begin Try
					Set @CmdFiles='Alter database [' + @dbname + '] modify file (name= [' + @FName + '], filegrowth='+ @SuggestedGrowthSize +'MB)'
					print @CmdFiles
					Exec sp_executesql @CmdFiles
					Update @FileResult 
					Set AutogrowthSize = @SuggestedGrowthSize, AutoGrowthType = 'MB'
					where Fname=@FName
				End Try 
				Begin Catch 
					Update @FileResult 
					Set AutoGrowthType='##PB##', Error = ERROR_MESSAGE()
					where fname = @FName
				End Catch
			end
			--INITIAL FILESIZE
			if @DBname = 'model'
			begin
				if @InitialSize < '12800' -- ( number of 8KB pages to reach 100MB)
					begin try
						Set @CmdFiles='Alter database [' + @dbname + '] modify file (name= [' + @FName + '], size = 100 MB)'
						print @CmdFiles
						Exec sp_executesql @CmdFiles
						Update @FileResult 
						Set InitialSize = '100 MB'
						where Fname=@FName
					end try
					begin catch
						Update @FileResult 
						Set InitialSize = '##PB##', Error = ERROR_MESSAGE()
						where fname = @FName
					end catch
			end		
		end		
		update @FileResult
		set Treated = 1 
		where Fname = @FName
	end
	
	--Showing errors
	if exists
	(
		select 1
		from @FileResult
		where AutoGrowthType = '##PB##' or InitialSize = '##PB##'
	)
		select *
		from @FileResult
		where AutoGrowthType = '##PB##' or InitialSize = '##PB##'
	else
		print 'File options modified successfully'
	
	/*
		-------------------------------------------------------------
		---------------------DATABASE OPTIONS------------------------
		-------------------------------------------------------------
	*/
	if not exists
	(
		select 1
		from sys.sysservers
		where srvname = 'SEGOTN10232'
	)
		exec sp_addlinkedserver SEGOTN10232
				
	if OBJECT_ID('TempDB.dbo.#DBResult') is not NULL
		drop table #DBResult
	create table #DBResult
	(
		InstanceName			sysname, 
		DbName					sysname,
		Is_Auto_Close_On		varchar(6),
		Is_Auto_Shrink_On		varchar(6),
		Page_Verify_option_Desc	nvarchar(60),
		compatibility_level		varchar(100),
		CompLevelToKeep			int,
		Error					nvarchar(2048),
		Treated					bit
	)

	insert into #DBResult
	select
		@ServerName,				--InstanceName
		name,						--Dbname
		is_auto_close_on,			--Is_Auto_Close_On
		is_auto_shrink_on,			--Is_Auto_Shrink_On
		page_verify_option_desc,	--Page_Verify_option_Desc
		compatibility_level,		--compatibiliyy_level
		0,							--CompLevelToKeep
		'',							--Error
		0							--Treated
	from sys.databases
	while exists
	(
		select 1
		from #DBResult
		where Treated <> 1
		and DbName is not NULL	--to avoid infinite loop in case there is no record
	)
	begin
		select top 1
			@ServerName =				InstanceName,
			@DBname =					Dbname,
			@is_auto_close_on =			is_auto_close_on,
			@is_auto_shrink_on =		is_auto_shrink_on,
			@page_verify_option_desc =	page_verify_option_desc,
			@compatibility_level =		compatibility_level
		from #DBResult 
		where Treated <> 1
		order by DbName
		
		--AUTOCLOSE
		if @is_auto_close_on <> '0'
		Begin Try 
			Set @CmdDBOptions='ALTER DATABASE [' + @DBname + '] SET AUTO_CLOSE OFF WITH NO_WAIT'
			print @CmdDBOptions
			Exec sp_executesql @CmdDBOptions
			Update #DBResult 
			Set is_auto_close_on = '0' 
			where Dbname = @dbname
		End Try 
		Begin Catch 
			Update #DBResult 
			Set is_auto_close_on = '##PB##', Error = ERROR_MESSAGE() 
			where Dbname=@dbname
		End Catch 
		
		--AUTOSHRINK
		if @Is_Auto_Shrink_On <> '0'
		Begin Try 
			Set @CmdDBOptions='ALTER DATABASE [' + @DBname + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
			print @CmdDBOptions
			Exec sp_executesql @CmdDBOptions
			Update #DBResult 
			Set Is_Auto_Shrink_On = '0' 
			where Dbname = @dbname
		End Try 
		Begin Catch 
			Update #DBResult 
			Set Is_Auto_Shrink_On = '##PB##', Error = ERROR_MESSAGE() 
			where Dbname=@dbname
		End Catch
		
		if @DBname not in ('master','model','msdb','tempdb')	--system databases only checked for
																--autoclose/autoshrink
		begin
			--PAGE VERIFY
			if @page_verify_option_desc <> 'CHECKSUM'
			Begin Try 
				Set @CmdDBOptions='ALTER DATABASE [' + @DBname + '] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT'
				print @CmdDBOptions
				Exec sp_executesql @CmdDBOptions
				Update #DBResult 
				Set page_verify_option_desc = 'CHECKSUM' 
				where Dbname = @dbname
			End Try 
			Begin Catch 
				Update #DBResult 
				Set page_verify_option_desc = '##PB##', Error = ERROR_MESSAGE() 
				where Dbname = @dbname
			End Catch 
			
			--COMPATIBILITY LEVEL			
			
		end
		update #DBResult
		set Treated = 1 
		where DbName = @DBname
	end
	
	exec sp_dropserver  SEGOTN10232
	
	--Showing errors
	if exists
	(
		select 1
		from #DBResult
		where is_auto_close_on = '##PB##' or Is_Auto_Shrink_On = '##PB##' or page_verify_option_desc = '##PB##'
		or compatibility_level = '##PB##'
	)
		select *
		from #DBResult
		where is_auto_close_on = '##PB##' or Is_Auto_Shrink_On = '##PB##' or page_verify_option_desc = '##PB##'
		or compatibility_level = '##PB##'
	else
		print 'Database options modified successfully'
	
	drop table #DBResult
	
	/*
		-------------------------------------------------------------
		---------------------INSTANCE OPTIONS------------------------
		-------------------------------------------------------------
	*/
	declare @InstanceResult table 
	(
		InstanceName			varchar(50),
		ServerPhysicalMemory	varchar(50),
		MinServerMemory			varchar(50),
		MaxServerMemory			varchar(50),
		NumberOfInstances		tinyint,
		ProcArchi				varchar(3),
		AWE_Enabled				varchar(6),
		OLE_Automation			varchar(6),
		XPCmdShell				varchar(6),
		RemoteAdminConnections	varchar(6),
		NumberOfCores			tinyint,
		NumberOfPhysicalCPUs	tinyint,
		NumberOfNumaNodes		tinyint,
		MaxDOP					varchar(6),
		Error					nvarchar(2048)
	)
	set @ServerName = @@SERVERNAME
	insert into @InstanceResult (InstanceName) 
	values 	(@ServerName)	
	
	--XP_CMDSHELL
	--Has to be the first to be set because used to get number of instances
	set @XPCmdShell =
	(
		select convert(varchar(6),value)
		from sys.configurations 
		where name = 'xp_cmdshell'
	)
	update @InstanceResult 
	set XPCmdShell = @XPCmdShell
	if @XPCmdShell <> '1'
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'xp_cmdshell', '1'
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult 
		set XPCmdShell = '1'
	end try
	begin catch
		update @InstanceResult 
		set XPCmdShell = '##PB##', Error = ERROR_MESSAGE()
	end catch
	
	--OLE AUTOMATION
	set @OLE_Automation =
	(
		select convert(varchar(6),value)
		from sys.configurations 
		where name = 'Ole Automation Procedures'
	)
	update @InstanceResult 
	set OLE_Automation = @OLE_Automation 
	if @OLE_Automation <> '1' 
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'Ole Automation Procedures', '1'
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult 
		set OLE_Automation = '1' 
	end try
	begin catch
		update @InstanceResult 
		set OLE_Automation = '##PB##', Error = ERROR_MESSAGE()
	end catch
	
	--REMOTE ADMIN CONNECTIONS
	set @RemoteAdminConnections =
	(
		select convert(varchar(6),value)
		from sys.configurations 
		where name = 'remote admin connections'
	)
	update @InstanceResult 
	set RemoteAdminConnections = @RemoteAdminConnections
	if @RemoteAdminConnections <> '1'
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'remote admin connections', '1'
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult 
		set RemoteAdminConnections = '1'
	end try
	begin catch
		update @InstanceResult 
		set RemoteAdminConnections = '##PB##', Error = ERROR_MESSAGE()
	end catch
	
	--MEMORY
	--Min Memory and MaxMemory settings can be changed dynamically, without restarting the service
	--Min Memory
	set @MinServerMemory = 
	(
		select convert(varchar(50),value)							
		from sys.configurations
		where name = 'min server memory (MB)'
	)
	update @InstanceResult
	set MinServerMemory = @MinServerMemory
	if @MinServerMemory <> '0'
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'min server memory', '0';
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult
		set MinServerMemory = '0MB'
	end try
	begin catch
		update @InstanceResult
		set MinServerMemory = '##PB##', error = ERROR_MESSAGE()
	end catch
	
	--Max Memory
	set @ServerPhysicalMemoryMB =
	(
		select physical_memory_in_bytes / (1024*1024) 
		FROM sys.dm_os_sys_info
	)
	update @InstanceResult
	set ServerPhysicalMemory = @ServerPhysicalMemoryMB
	set @ServerPhysicalMemoryGB = @ServerPhysicalMemoryMB / 1024
	
	set @MaxServerMemory =
	(
		select convert(varchar(50),value)							
		from sys.configurations
		where name = 'max server memory (MB)'
	)
	update @InstanceResult
	set MaxServerMemory = @MaxServerMemory
	if charindex('X86',@@VERSION) > 0
		set @ProcArchi = 'X86'
	else
		set @ProcArchi = 'X64'
	update @InstanceResult
	set ProcArchi = @ProcArchi
	declare @RunningServices table
	(
		ServiceName	varchar(100)
	)
	insert into @RunningServices
	exec master.dbo.xp_cmdshell'NET START'
	set @NumberOfInstances =
	(
		select COUNT(1)
		from @RunningServices
		where ServiceName like '%SQL Server (%'
	) 
	update @InstanceResult
	set NumberOfInstances = @NumberOfInstances
	if @ProcArchi = 'X64' 
	and @MaxServerMemory = '2147483647' --default value = 2^31
	and @NumberOfInstances = 1	--only 1 instance running on the server
	begin
		if @ServerPhysicalMemoryGB < 2 set @MaxServerMemory = 0.8 * @ServerPhysicalMemoryGB
		if @ServerPhysicalMemoryGB >= 2 and @ServerPhysicalMemoryGB < 4 set @MaxServerMemory = 1500
		else if @ServerPhysicalMemoryGB >= 4 and @ServerPhysicalMemoryGB < 6 set @MaxServerMemory = 3200
		else if @ServerPhysicalMemoryGB <= 6 and @ServerPhysicalMemoryGB < 8 set @MaxServerMemory = 4800
		else if @ServerPhysicalMemoryGB <= 8 and @ServerPhysicalMemoryGB < 12 set @MaxServerMemory = 6400
		else if @ServerPhysicalMemoryGB <= 12 and @ServerPhysicalMemoryGB < 16 set @MaxServerMemory = 10000
		else if @ServerPhysicalMemoryGB <= 16 and @ServerPhysicalMemoryGB < 24 set @MaxServerMemory = 13500
		else if @ServerPhysicalMemoryGB <= 24 and @ServerPhysicalMemoryGB < 32 set @MaxServerMemory = 21500
		else if @ServerPhysicalMemoryGB <= 32 and @ServerPhysicalMemoryGB < 48 set @MaxServerMemory = 29000
		else if @ServerPhysicalMemoryGB <= 48 and @ServerPhysicalMemoryGB < 64 set @MaxServerMemory = 44000
		else if @ServerPhysicalMemoryGB <= 64 and @ServerPhysicalMemoryGB < 72 set @MaxServerMemory = 60000
		else if @ServerPhysicalMemoryGB <= 72 and @ServerPhysicalMemoryGB < 96 set @MaxServerMemory = 68000
		else if @ServerPhysicalMemoryGB <= 96 and @ServerPhysicalMemoryGB < 128 set @MaxServerMemory = 92000
		else set @MaxServerMemory = 124000
		begin try
			exec sp_configure 'show advanced option', '1'
			RECONFIGURE
			exec sp_configure 'max server memory', @MaxServerMemory;
			RECONFIGURE WITH OVERRIDE
			update @InstanceResult
			set MaxServerMemory = @MaxServerMemory
		end try
		begin catch
			update @InstanceResult
			set MaxServerMemory = '##PB##', error = ERROR_MESSAGE()
		end catch		
	end
	
	--AWE
	/* AWE should be:
	-enabled on 32-bit instances with more than 4 GB of RAM available
	-disabled on 64-bit systems */
	set @AWE_Enabled =
	(
		select convert(varchar(6),value)
		from sys.configurations
		where name = 'awe enabled'
	)
	update @InstanceResult 
	set AWE_Enabled = @AWE_Enabled
	if @ProcArchi = 'X64' 
		set @AWE_Enabled = '0'
	else if @ServerPhysicalMemoryMB >= 4096
		set @AWE_Enabled = '1'
	if @AWE_Enabled <> (select AWE_Enabled from @InstanceResult)
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'awe enabled', @AWE_Enabled;
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult 
		set AWE_Enabled = @AWE_Enabled
	end try
	begin catch
		update @InstanceResult 
		set AWE_Enabled = '##PB##', Error = ERROR_MESSAGE()
	end catch	
	
	--CPU / MAXDOP
	/*	
		Use the following guidelines to configure the MaxDOP value (apply all rules):
		-MaxDOP must never exceed 8.
		-For a server with multiple NUMA nodes, set MaxDOP to the number of cores per NUMA node.
		-For a server with no NUMA nodes, set MaxDOP to 4/5 times the number of cores and round the value down to the closest integer. E.g. 6 cores will give MaxDOP 4.
		-For a server with hyper-threading enabled, MaxDOP must not exceed the number of physical cores.
	*/

	set @NumberOfCores = 
	(
		select cpu_count
		from sys.dm_os_sys_info
	)
	
	update @InstanceResult 
	set NumberOfCores = @NumberOfCores
	
	set	@NumberOfPhysicalCPUs = --Not used yet
	(
		select cpu_count / hyperthread_ratio
		from sys.dm_os_sys_info
	)
	update @InstanceResult 
	set NumberOfPhysicalCPUs = @NumberOfPhysicalCPUs

	set @NumberOfNumaNodes =
	(
		select count(distinct memory_node_id) 
		from sys.dm_os_memory_clerks 
		where memory_node_id <> 64
	)
	
	update @InstanceResult 
	set NumberOfNumaNodes = @NumberOfNumaNodes
	
	set @MaxDOP =
	(
		select convert(varchar(6),value)
		from sys.configurations
		where name = 'max degree of parallelism'
	)
	update @InstanceResult 
	set MaxDOP = @MaxDOP
	
	if @NumberOfNumaNodes > 1
		set @MaxDOP = @NumberOfCores / @NumberOfNumaNodes;
	else
		set @MaxDOP = @NumberOfCores * 4 / 5;
	if @MaxDOP > 8 
		set @MaxDOP = 8;
	
	--From meeting: aim = never set a value > to the current setting 
	if @MaxDOP <				--Optimal value	
	(
		select MaxDop
		from @InstanceResult	--current setting
	)
	begin try
		exec sp_configure 'show advanced option', '1'
		RECONFIGURE
		exec sp_configure 'max degree of parallelism', @MaxDOP
		RECONFIGURE WITH OVERRIDE
		update @InstanceResult 
		set MaxDOP = @MaxDOP
	end try
	begin catch
		update @InstanceResult 
		set MaxDOP = '##PB##', Error = ERROR_MESSAGE()
	end catch	
	
	--Showing errors
	if exists
	(
		select 1
		from @InstanceResult
		where XPCmdShell = '##PB##' or OLE_Automation = '##PB##' or RemoteAdminConnections = '##PB##'
		or MinServerMemory = '##PB##' or MaxServerMemory = '##PB##' or AWE_Enabled = '##PB##'
		or MaxDOP = '##PB##'
	)
		select *
		from @InstanceResult
		where XPCmdShell = '##PB##' or OLE_Automation = '##PB##' or RemoteAdminConnections = '##PB##'
		or MinServerMemory = '##PB##' or MaxServerMemory = '##PB##' or AWE_Enabled = '##PB##'
		or MaxDOP = '##PB##'
	else
		print 'Instance options modified successfully'
	
end


