/* Create Table */

USE [master]
GO

IF  EXISTS (SELECT * FROM sysobjects WHERE name='Database_Space_Tracker' AND type in (N'U'))
DROP TABLE [dbo].[Database_Space_Tracker]
GO

USE [master]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Database_Space_Tracker](
	[Server_Name] [sysname] NOT NULL,
	[Database_Name] [sysname] NOT NULL,
	[DB_SizeMB] [numeric](10, 2) NOT NULL,
	[DB_UsedSpaceMB] [numeric](10, 2) NOT NULL,
	[DB_UnusedSpaceMB] [numeric](10, 2) NOT NULL,
	[Capture_Date] [date] NOT NULL,
 CONSTRAINT [PK_Database_Space_Tracker] PRIMARY KEY CLUSTERED 
(
	[Server_Name] ASC,
	[Database_Name] ASC,
	[Capture_Date] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
-------------------------------------------------------------------------------------------------------------
/* Create Job */


USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'DB_Growth_Tracker')
EXEC msdb.dbo.sp_delete_job @job_name='DB_Growth_Tracker'
GO

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DB_Growth_Tracker', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'To Capture Database Size.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Capture]    Script Date: 06/04/2014 13:40:56 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Capture', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE master
GO

declare @ssql nvarchar(4000)
set @ssql= ''
        if ''''?'''' NOT in (''''master'''',''''model'''',''''msdb'''',''''tempdb'''') begin
        use [?]
        select
		CONVERT(sysname,SERVERPROPERTY(''''servername'''')),
		DB_NAME(),
		sum(convert(numeric(10,2),round(a.size/128.,2))),
		sum(convert(numeric(10,2),round(fileproperty( a.name,''''SpaceUsed'''')/128.,2))),
		sum(convert(numeric(10,2),round((a.size-fileproperty( a.name,''''SpaceUsed''''))/128.,2))),
		convert(date,getdate())
		from sysfiles a where a.groupid=1
		end''
		
INSERT INTO Database_Space_Tracker exec sp_MSforeachdb @ssql', 
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
		@active_end_date=99991231, 
		@active_start_time=234500, 
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






