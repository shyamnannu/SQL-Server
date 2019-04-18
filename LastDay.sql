select dateadd(m, datediff(m, 0, dateadd(MM, -1,getdate())), 0) as [Date of First Day of Last Month] 
select dateadd(m, datediff(m, 0, dateadd(m, 1, dateadd(MM, -1,getdate()))), -1) as [Date of Last Day of Last Month]
----------------------------------------------------------
SELECT CONVERT(Date,DATEADD(m,-1, Dateadd(d,1-DATEPART(d,getdate()),GETDATE()))) AS [FIRST DAY]

select CONVERT(Date,Dateadd(d,-DATEPART(Day,getdate()),GETDATE())) AS [LAST DAY]