USE [master]
GO

/****** Object:  Table [dbo].[disk_size]    Script Date: 05/24/2013 08:04:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[disk_size](
	[vol_lbl] [varchar](50) NULL,
	[vol_name] [varchar](100) NULL,
	[TotalSize_gb] [decimal](20, 2) NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

USE [master]
GO

/****** Object:  Table [dbo].[vol_space]    Script Date: 05/24/2013 08:04:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[vol_space](
	[free_gb] [numeric](18, 2) NOT NULL,
	[vol_lbl] [varchar](50) NULL,
	[vol_name] [varchar](50) NOT NULL,
	[percent_free] [numeric](18, 2) NOT NULL,
	[size_gb] [numeric](18, 2) NOT NULL,
	[server_name] [varchar](50) NOT NULL,
	[dt] [datetime] NOT NULL,
 CONSTRAINT [PK_vol_space] PRIMARY KEY CLUSTERED 
(
	[server_name] ASC,
	[vol_name] ASC,
	[dt] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO


USE [master]
GO

/****** Object:  StoredProcedure [dbo].[vol_space_tracker]    Script Date: 05/24/2013 08:04:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[vol_space_tracker]
AS

CREATE TABLE #FreeSize
(vol_name varchar(50),
FreeSize_mb Numeric(18,2)
)
INSERT INTO #FreeSize EXEC ('xp_fixeddrives')

INSERT INTO dbo.vol_space

SELECT (f.FreeSize_mb/1024),d.vol_lbl,f.vol_name,
((f.FreeSize_mb/1024)*100/d.TotalSize_gb),d.TotalSize_gb,
convert(varchar(50),@@SERVERNAME),REPLACE(CONVERT(VARCHAR, getdate(),111),'/','-')
FROM #FreeSize f JOIN dbo.disk_size d
ON f.vol_name=d.vol_name

DROP TABLE #FreeSize

GO

USE [msdb]
GO

/****** Object:  Job [Volume_Space_Tracker]    Script Date: 05/24/2013 08:04:52 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 05/24/2013 08:04:52 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Volume_Space_Tracker', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run SP]    Script Date: 05/24/2013 08:04:52 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run SP', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [master].[dbo].[vol_space_tracker]', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20130524, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

