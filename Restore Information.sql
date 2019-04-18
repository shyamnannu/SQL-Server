SELECT [rs].[destination_database_name], 
[rs].[restore_date],
CASE [rs].[restore_type]
WHEN 'D' THEN 'FULL'
WHEN 'I' THEN 'DIFFERENTIAL'
WHEN 'L' THEN 'LOG'
END AS [Backup_Type], 
CASE [rs].[recovery]
WHEN '0' THEN 'NORECOVERY'
WHEN '1' THEN 'RECOVERY'
END AS [recovery_option],
[bs].[backup_start_date], 
[bs].[backup_finish_date],
CASE 
WHEN [rs].[stop_at] IS NULL THEN [bs].[backup_finish_date]
ELSE [rs].[stop_at]
END AS [Backup_stopped_at],
[bs].[server_name] as [Source_Server_name],
[bs].[database_name] as [source_database_name], 
[bmf].[physical_device_name] as [backup_file_used_for_restore]
FROM msdb..restorehistory rs
INNER JOIN msdb..backupset bs
ON [rs].[backup_set_id] = [bs].[backup_set_id]
INNER JOIN msdb..backupmediafamily bmf 
ON [bs].[media_set_id] = [bmf].[media_set_id] 
WHERE [rs].[destination_database_name] ='MP1'
ORDER BY [rs].[restore_date] DESC