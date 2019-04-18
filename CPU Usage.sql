DECLARE @ts_now BIGINT

select @ts_now = cpu_ticks / (cpu_ticks/ms_ticks) from sys.dm_os_sys_info

SELECT record_id,
Dateadd(ms, -1 * ( @ts_now - [timestamp] ), Getdate()) AS eventtime,
sqlprocessutilization,
systemidle,
100 - systemidle - sqlprocessutilization AS
otherprocessutilization
FROM (SELECT record.value('(./Record/@id)[1]', 'int')
AS record_id,
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]',
'int')
AS systemidle,
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sqlprocessutilization,
timestamp
FROM (SELECT timestamp,
CONVERT(XML, record) AS record
FROM sys.dm_os_ring_buffers
WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
AND record LIKE '%%') AS x) AS y
ORDER BY record_id DESC


