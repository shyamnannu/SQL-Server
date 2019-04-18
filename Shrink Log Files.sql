declare @ssql nvarchar(4000)
set @ssql= '
        if ''?'' NOT in (''master'',''model'',''msdb'',''tempdb'') begin
        use [?]
        declare @tsql nvarchar(4000) set @tsql = ''''
        declare @iLogFile int
        declare LogFiles cursor for
        select fileid from sysfiles where  status & 0x40 = 0x40
        open LogFiles
        fetch next from LogFiles into @iLogFile
        while @@fetch_status = 0
        begin
          set @tsql = @tsql + ''DBCC SHRINKFILE(''+cast(@iLogFile as varchar(5))+'', 1) ''
          fetch next from LogFiles into @iLogFile
        end
        exec(@tsql)
        close LogFiles
        DEALLOCATE LogFiles
        end'

exec sp_MSforeachdb @ssql
