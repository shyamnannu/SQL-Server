Declare @dbid int

Select @dbid = db_id('MyDatabase')

Select objectname=object_name(i.object_id)

, indexname=i.name, i.index_id

, o.create_date, o.modify_date

from sys.indexes i, sys.objects o

where o.type_desc='USER_TABLE'
and i.index_id >0
and o.object_id = i.object_id

order by objectname,i.index_id,indexname asc
--------------------------------------------------
Select distinct(object_name(i.object_id)) as objectname
,schema_name(o.schema_id) as Schemaname
,st.row_count
from sys.indexes i, sys.objects o,sys.dm_db_partition_stats st
where o.type_desc='USER_TABLE'
and i.index_id >0
and o.object_id = i.object_id
and o.object_id=st.object_id
and o.modify_date < DATEADD(DD, -4, GETDATE())
and st.row_count < 200001 
order by st.row_count,object_name(i.object_id) desc
