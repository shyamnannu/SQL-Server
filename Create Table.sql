USE [VIT_GLOBAL_TOOLBOX]
GO

/****** Object:  Table [dbo].[LogicalFileName]    Script Date: 10/05/2012 12:02:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[LogicalFileName](
	[database_name] [nvarchar](100) NOT NULL,
	[fileid] [int] NOT NULL,
	[name] [nvarchar](500) NOT NULL
) ON [PRIMARY]

GO

USE [VIT_GLOBAL_TOOLBOX]
GO


INSERT INTO [dbo].[LogicalFileName] SELECT DB_NAME(dbid),fileid,name FROM sys.sysaltfiles WHERE dbid > 4 and dbid <> 32767
GO


CREATE TABLE #LogicalFileName
	([database_name] [nvarchar](100) NOT NULL,
	[fileid] [int] NOT NULL,
	[name] [nvarchar](500) NOT NULL
) 

declare @ssql nvarchar(4000)
set @ssql= '
        if ''?'' in (''master'',''model'',''msdb'') begin
        use [?]
        select db_name(),fileid,name from sys.sysfiles
        end'

insert into #LogicalFileName exec sp_msforeachdb @ssql

select * from #LogicalFileName

DROP TABLE  #LogicalFileName

