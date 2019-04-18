SELECT
    spid
    ,sp.STATUS
    ,loginame   = SUBSTRING(loginame, 1, 12)
    ,hostname   = SUBSTRING(hostname, 1, 12)
    ,hostprocess
    ,blk        = CONVERT(CHAR(3), blocked)
    ,open_tran
    ,dbname     = SUBSTRING(DB_NAME(sp.dbid),1,10)
    ,cmd
    ,wait_resource
    ,waittype
    ,waittime
    ,last_batch
    ,SQLStatement       =
        SUBSTRING
        (
            qt.text,
            er.statement_start_offset/2,
            (CASE WHEN er.statement_end_offset = -1
                THEN LEN(CONVERT(nvarchar(MAX), qt.text)) * 2
                ELSE er.statement_end_offset
                END - er.statement_start_offset)/2
        )
FROM master.dbo.sysprocesses sp
LEFT JOIN sys.dm_exec_requests er
    ON er.session_id = sp.spid
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE spid IN (SELECT blocked FROM master.dbo.sysprocesses)
AND blocked = 0
--------------------------------------------------------------------------------------------------------------------
DECLARE @cmdKill VARCHAR(50)

DECLARE killCursor CURSOR FOR
SELECT 'KILL ' + Convert(VARCHAR(5), spid)
from sys.sysprocesses
where spid in (select distinct blocked from sys.sysprocesses where blocked <>0) and blocked =0

OPEN killCursor
FETCH killCursor INTO @cmdKill

WHILE 0 = @@fetch_status
BEGIN
PRINT (@cmdKill) 
FETCH killCursor INTO @cmdKill
END

CLOSE killCursor
DEALLOCATE killCursor 