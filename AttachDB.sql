Create Proc usp_attachDB @db sysname = NULL as
SET NOCOUNT ON
SET CONCAT_NULL_YIELDS_NULL OFF
Declare @cmd varchar(1000)
Declare @a Varchar(2000)
Declare @Filecnt int
Declare @cnt int
Declare @sq char(1)
Declare @dq char(2)
Declare @TempFilename Varchar(1000)
Declare @TempFilename1 Varchar(1000) 


set @sq = ''''
set @dq = ''''''
set @cnt = 1

If @db is not NULL
Begin
  Create table #1 (fileid int,filename sysname,name sysname)
  SET @cmd = 'Insert into #1 (fileid,filename,name) Select fileid,filename,name from ' + QuoteName(@db)  + '.dbo.sysfiles'
  exec (@cmd)
  select @filecnt =  max(fileid) from #1
  While @cnt <= @filecnt
  Begin 
    Select @TempFileName = filename from #1 where fileid = @cnt
    Select @TempFileName = rtrim(@TempFileName)
    Select @a = @a+','+CHAR(13)+CHAR(9)
    Select  @a = @a  +'@filename'+Convert(varchar(2),@cnt)+' = '+@sq+@TempFilename+@sq
    Set @cnt = @cnt + 1
  End
  Select @a = 'EXEC sp_attach_db @dbname = ' +@sq+@db+@sq+@a
  print @a
End

Else
  Begin

  declare db_cursor cursor for 
  Select name from sysdatabases Where name != 'tempdb' order by dbid
  open db_cursor 
  fetch next from db_cursor into @db
  while @@fetch_status = 0 
    begin 
    Create table #2 (fileid int,filename sysname,name sysname)
    SET @cmd = 'Insert into #2 (fileid,filename,name) Select fileid,filename,name from ' + QuoteName(@db)  + '.dbo.sysfiles'
    exec (@cmd)
    select @filecnt =  max(fileid) from #2
      While @cnt <= @filecnt
      Begin 
      Select @TempFileName = filename from #2 where fileid = @cnt
      Select @TempFileName = rtrim(@TempFileName)
      Select @a = @a+', '+CHAR(13)+CHAR(9)
      Select  @a = @a  +'@filename'+Convert(varchar(2),@cnt)+' = '+@sq+@TempFilename+@sq
      Set @cnt = @cnt + 1
      End
    Select @a = 'EXEC sp_attach_db @dbname = ' +@sq+@db+@sq+@a
    Print @a
    Print 'GO' 
    Select @a = ' '
    drop table #2
    set @cnt = 1
    fetch next from db_cursor into @db
    end 
  close db_cursor 
  deallocate db_cursor 
  end
