select
	t1.session_id
	, t1.request_id
	, task_alloc_GB = cast((t1.task_alloc_pages * 8./1024./1024.) as numeric(10,1))
	, task_dealloc_GB = cast((t1.task_dealloc_pages * 8./1024./1024.) as numeric(10,1))
	, host= case when t1.session_id <=50 then 'SYS' else s1.host_name end
	, s1.login_name
	, s1.status
	, s1.last_request_start_time
	, s1.last_request_end_time
	, s1.row_count
	, s1.transaction_isolation_level
    , query_text=
		coalesce((SELECT SUBSTRING(text, t2.statement_start_offset/2 + 1,
          (CASE WHEN statement_end_offset = -1
              THEN LEN(CONVERT(nvarchar(max),text)) * 2
                   ELSE statement_end_offset
              END - t2.statement_start_offset)/2)
		FROM sys.dm_exec_sql_text(t2.sql_handle)) , 'Not currently executing')
	, query_plan=(SELECT query_plan from sys.dm_exec_query_plan(t2.plan_handle))
from
	(Select session_id, request_id
	, task_alloc_pages=sum(internal_objects_alloc_page_count +   user_objects_alloc_page_count)
	, task_dealloc_pages = sum (internal_objects_dealloc_page_count + user_objects_dealloc_page_count)
	from sys.dm_db_task_space_usage
	group by session_id, request_id) as t1
left join sys.dm_exec_requests as t2 on
	t1.session_id = t2.session_id
	and t1.request_id = t2.request_id
left join sys.dm_exec_sessions as s1 on
	t1.session_id=s1.session_id
where
	t1.session_id > 50 -- ignore system unless you suspect there's a problem there
	and t1.session_id <> @@SPID -- ignore this request itself
order by t1.task_alloc_pages DESC

----------------------------------------------------------------------------------
;WITH task_space_usage AS (
    -- SUM alloc/delloc pages
    SELECT session_id,
           request_id,
           SUM(internal_objects_alloc_page_count) AS alloc_pages,
           SUM(internal_objects_dealloc_page_count) AS dealloc_pages
    FROM sys.dm_db_task_space_usage WITH (NOLOCK)
    WHERE session_id <> @@SPID
    GROUP BY session_id, request_id
)
SELECT TSU.session_id,
       TSU.alloc_pages * 1.0 / 128 AS [internal object MB space],
       TSU.dealloc_pages * 1.0 / 128 AS [internal object dealloc MB space],
       EST.text,
       -- Extract statement from sql text
       ISNULL(
           NULLIF(
               SUBSTRING(
                   EST.text, 
                   ERQ.statement_start_offset / 2, 
                   CASE WHEN ERQ.statement_end_offset < ERQ.statement_start_offset THEN 0 ELSE( ERQ.statement_end_offset - ERQ.statement_start_offset ) / 2 END
               ), ''
           ), EST.text
       ) AS [statement text],
       EQP.query_plan
FROM task_space_usage AS TSU
INNER JOIN sys.dm_exec_requests ERQ WITH (NOLOCK)
    ON  TSU.session_id = ERQ.session_id
    AND TSU.request_id = ERQ.request_id
OUTER APPLY sys.dm_exec_sql_text(ERQ.sql_handle) AS EST
OUTER APPLY sys.dm_exec_query_plan(ERQ.plan_handle) AS EQP
WHERE EST.text IS NOT NULL OR EQP.query_plan IS NOT NULL
ORDER BY 3 DESC, 5 DESC
