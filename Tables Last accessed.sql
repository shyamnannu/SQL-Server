SELECT DB_NAME(ius.[database_id]) AS [Database],
OBJECT_NAME(ius.[object_id]) AS [TableName],
MAX(ius.[last_user_lookup]) AS [last_user_lookup],
MAX(ius.[last_user_scan]) AS [last_user_scan],
MAX(ius.[last_user_seek]) AS [last_user_seek]
FROM sys.dm_db_index_usage_stats AS ius
WHERE ius.[database_id] = DB_ID()
--AND ius.[object_id] = OBJECT_ID('YourTableName')
GROUP BY ius.[database_id], ius.[object_id];
-----------------------------------------------------
SELECT db.name, 
(SELECT MAX(T) AS last_access FROM(SELECT MAX(last_user_lookup) AS T UNION ALL SELECT MAX(last_user_seek) UNION ALL SELECT MAX(last_user_scan) UNION ALL SELECT MAX(last_user_update)) d) last_access
FROM sys.databases db 
LEFT JOIN sys.dm_db_index_usage_stats iu ON db.database_id = iu.database_id
GROUP BY db.database_id, db.name
ORDER BY last_access
-----------------------------------------------------
SELECT db.name, 
(SELECT MAX(T) AS last_user_update FROM(SELECT MAX(last_user_update) AS T UNION ALL SELECT MAX(last_user_seek) UNION ALL SELECT MAX(last_user_scan) UNION ALL SELECT MAX(last_user_lookup)) d) last_user_update
FROM sys.databases db 
LEFT JOIN sys.dm_db_index_usage_stats iu ON db.database_id = iu.database_id
GROUP BY db.database_id, db.name
ORDER BY last_user_update