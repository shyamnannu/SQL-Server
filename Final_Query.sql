USE [MyDatabase]
GO

Truncate table [dbo].[vol_space_all]
GO

INSERT INTO [MyDatabase].[dbo].[vol_space_all]
SELECT st.free_gb
,st.vol_lbl
,st.vol_name
,st.percent_free
,st.size_gb
,UPPER(dr.Instance_name) AS Instance_name
,st.dt FROM dbo.vol_space_Stalone st
JOIN dbo.sql_drive_info dr
ON st.server_name=dr.host_name and left(st.vol_name,3)=dr.drive
where dt between CONVERT(Date,DATEADD(m,-1, Dateadd(d,1-DATEPART(d,getdate()),GETDATE())))
and CONVERT(Date,Dateadd(d,-DATEPART(Day,getdate()),GETDATE()))

GO

INSERT INTO [MyDatabase].[dbo].[vol_space_all]
SELECT st.free_gb
,st.vol_lbl
,st.vol_name
,st.percent_free
,st.size_gb
,dr.Instance_name
,st.dt FROM dbo.vol_space_clu st
JOIN dbo.sql_drive_info dr
ON st.server_name=dr.host_name and left(st.vol_name,3)=dr.drive
where dt between CONVERT(Date,DATEADD(m,-1, Dateadd(d,1-DATEPART(d,getdate()),GETDATE())))
and CONVERT(Date,Dateadd(d,-DATEPART(Day,getdate()),GETDATE()))
order by Instance_name,vol_name,dt

GO
