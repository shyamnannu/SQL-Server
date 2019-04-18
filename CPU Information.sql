SELECT TOP 50 qs.creation_time, qs.execution_count, qs.total_worker_time as total_cpu_time, qs.max_worker_time as max_cpu_time, qs.total_elapsed_time, qs.max_elapsed_time, qs.total_logical_reads, qs.max_logical_reads, qs.total_physical_reads, qs.max_physical_reads,t.[text], qp.query_plan, t.dbid, t.objectid, t.encrypted, qs.plan_handle, qs.plan_generation_num FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp ORDER BY qs.total_worker_time DESC
-------------------------------------------------------------------------------
SELECT TOP 50
	[Avg. MultiCore/CPU time(sec)] = qs.total_worker_time / 1000000 / qs.execution_count,
	[Total MultiCore/CPU time(sec)] = qs.total_worker_time / 1000000,
	[Avg. Elapsed Time(sec)] = qs.total_elapsed_time / 1000000 / qs.execution_count,
	[Total Elapsed Time(sec)] = qs.total_elapsed_time / 1000000,
	qs.execution_count,
	[Avg. I/O] = (total_logical_reads + total_logical_writes) / qs.execution_count,
	[Total I/O] = total_logical_reads + total_logical_writes,
	Query = SUBSTRING(qt.[text], (qs.statement_start_offset / 2) + 1,
		(
			(
				CASE qs.statement_end_offset
					WHEN -1 THEN DATALENGTH(qt.[text])
					ELSE qs.statement_end_offset
				END - qs.statement_start_offset
			) / 2
		) + 1
	),
	Batch = qt.[text],
	[DB] = DB_NAME(qt.[dbid]),
	qs.last_execution_time,
	qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.[sql_handle]) AS qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
where qs.execution_count > 5	--more than 5 occurences
ORDER BY [Total MultiCore/CPU time(sec)] DESC
----------------------------------------------------
--CUrrent queries

SELECT 
	r.session_id
	,st.TEXT AS batch_text
	,SUBSTRING(st.TEXT, statement_start_offset / 2 + 1, (
			(
				CASE 
					WHEN r.statement_end_offset = - 1
						THEN (LEN(CONVERT(NVARCHAR(max), st.TEXT)) * 2)
					ELSE r.statement_end_offset
					END
				) - r.statement_start_offset
			) / 2 + 1) AS statement_text
	,qp.query_plan AS 'XML Plan'
	,r.*
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
ORDER BY cpu_time DESC