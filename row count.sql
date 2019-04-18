SELECT OBJECT_NAME(st.object_id) TableName, st.row_count,ob.type_desc
FROM sys.dm_db_partition_stats st join sys.objects ob
on st.object_id=ob.object_id
WHERE st.index_id < 2 and ob.type='U'
ORDER BY st.row_count DESC
GO