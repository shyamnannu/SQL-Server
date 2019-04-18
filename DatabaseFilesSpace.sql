select
[FileSizeMB] =
convert(numeric(10,2),round(a.size/128.,2)),
[UsedSpaceMB] =
convert(numeric(10,2),round(fileproperty( a.name,'SpaceUsed')/128.,2)) ,
[UnusedSpaceMB] =
convert(numeric(10,2),round((a.size-fileproperty( a.name,'SpaceUsed'))/128.,2)) ,
[DBFileName] = a.name
from
sysfiles a

---------------------------------------------------------
SELECT

(select sum(convert(float,size)) from dbo.sysfiles where (status & 64 = 0)) AS [DbSize],

(select sum(convert(float,reserved)) from dbo.sysindexes where indid in (0, 1, 255)) AS [SpaceUsed],

(select sum(convert(float,size)) from dbo.sysfiles where (status & 64 <> 0)) AS [LogSize],

((select sum(convert(float,dpages)) from dbo.sysindexes where indid < 2) + (select isnull(sum(convert(float,used)), 0) from dbo.sysindexes where indid = 255)) AS [DataSpaceUsage],

(select sum(convert(float,used)) from dbo.sysindexes where indid in (0, 1, 255)) AS [IndexSpaceTotal],

(select top 1 fg.groupname from dbo.sysfilegroups as fg where fg.status & 0x10 <> 0) AS [DefaultFileGroup]



SELECT

rtrim(s.name) AS [Name],

rtrim(s.filename) AS [FileName],

(s.size * 8) AS [Size],

CAST(CAST(FILEPROPERTY(s.name, 'SpaceUsed') AS float)* CONVERT(float,8) AS float) AS [UsedSpace],

CAST(s.fileid AS int) AS [ID]

FROM

dbo.sysfilegroups AS g

INNER JOIN dbo.sysfiles AS s ON s.groupid=CAST(g.groupid AS int)



SELECT

rtrim(s.name) AS [Name],

rtrim(s.filename) AS [FileName],

(s.size * 8)/1024 AS [Size],

CAST(FILEPROPERTY(s.name, 'SpaceUsed') AS float)* CONVERT(float,8)/1024 AS [UsedSpace],

CAST(s.fileid AS int) AS [ID]

FROM

dbo.sysfiles AS s
---------------------------------------------------------

SELECT

s.name AS [Name],

s.physical_name AS [FileName],

s.size * CONVERT(float,8) AS [Size],

CAST(CASE s.type WHEN 2 THEN 0 ELSE CAST(FILEPROPERTY(s.name, 'SpaceUsed') AS float)* CONVERT(float,8) END AS float) AS [UsedSpace],

s.file_id AS [ID]

FROM

sys.filegroups AS g

INNER JOIN sys.master_files AS s ON ((s.type = 2 or s.type = 0) and s.database_id = db_id() and (s.drop_lsn IS NULL)) AND (s.data_space_id=g.data_space_id)




SELECT

s.name AS [Name],

s.physical_name AS [FileName],

s.size * CONVERT(float,8) AS [Size],

CAST(FILEPROPERTY(s.name, 'SpaceUsed') AS float)* CONVERT(float,8) AS [UsedSpace],

s.file_id AS [ID]

FROM

sys.master_files AS s

WHERE
(s.type = 1 and s.database_id = db_id())

ORDER BY
[ID] ASC