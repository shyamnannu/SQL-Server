SET NOCOUNT ON

GO

SELECT Command

, 'PercentComplete' = percent_complete

, 'EstEndTime' = CONVERT(varchar(26),Dateadd(ms,estimated_completion_time,Getdate()),100)

, 'EstSecondsToEnd' = CONVERT(decimal(9,2),(estimated_completion_time * .001))

, 'EstMinutesToEnd' = CONVERT(decimal(9,2),(estimated_completion_time * .001 / 60))

, 'OperationStartTime' = CONVERT(varchar(26),start_time,100)
,  Session_id

FROM sys.dm_exec_requests

WHERE command IN ('BACKUP DATABASE','RESTORE DATABASE','RESTORE LOG','BACKUP LOG') 