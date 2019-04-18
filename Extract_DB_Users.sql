SET NOCOUNT ON
SELECT Scripts
FROM
(
SELECT getdate() AS ScriptDateTime,'CREATE USER ['+DP.name+'] FOR LOGIN ['+SP.name+']' 
		+ CASE WHEN DP.type_desc != 'WINDOWS_GROUP' 
			THEN ' WITH DEFAULT_SCHEMA = ['+ISNULL(DP.default_schema_name,'dbo')+']'--+ CHAR(13)+CHAR(10)+'GO'
			ELSE ''--+ CHAR(13)+CHAR(10)+'GO' 
		END AS Scripts
FROM SYS.DATABASE_PRINCIPALS DP,SYS.SERVER_PRINCIPALS SP
WHERE SP.SID = DP.SID
AND DP.name NOT IN ('DBO','GUEST','INFORMATION_SCHEMA','SYS','PUBLIC','DB_OWNER','DB_ACCESSADMIN','DB_SECURITYADMIN','DB_DDLADMIN',
'DB_BACKUPOPERATOR','DB_DATAREADER','DB_DATAWRITER','DB_DENYDATAREADER','DB_DENYDATAWRITER','DB_X')
UNION
--Extracting role membership
SELECT	getdate() AS ScriptDateTime,'EXEC sp_addrolemember @rolename =' 
	+ SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''') + ', @membername =' 
	+ SPACE(1) + QUOTENAME(USER_NAME(rm.member_principal_id), '''')
	--+ CHAR(13)+CHAR(10)+'GO' 
	AS '--Role Memberships'
FROM	sys.database_role_members AS rm
WHERE USER_NAME(rm.role_principal_id)+USER_NAME(rm.member_principal_id) != 'DB_OWNERDBO'
--ORDER BY rm.role_principal_id ASC
UNION
--Extracting object level permissions
SELECT	getdate() AS ScriptDateTime,CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END
	+ SPACE(1) + perm.permission_name + SPACE(1) + 'ON ' + QUOTENAME(USER_NAME(obj.schema_id)) + '.' + QUOTENAME(obj.name) 
	+ CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE '(' + QUOTENAME(cl.name) + ')' END
	+ SPACE(1) + 'TO' + SPACE(1) + QUOTENAME(USER_NAME(usr.principal_id)) COLLATE database_default
	+ CASE WHEN perm.state <> 'W' THEN SPACE(0) ELSE SPACE(1) + 'WITH GRANT OPTION' END
	--+ CHAR(13)+CHAR(10)+'GO' 
	AS '--Object Level Permissions'
FROM	sys.database_permissions AS perm
	INNER JOIN
	sys.objects AS obj
	ON perm.major_id = obj.[object_id]
	INNER JOIN
	sys.database_principals AS usr
	ON perm.grantee_principal_id = usr.principal_id
	LEFT JOIN
	sys.columns AS cl
	ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id

--ORDER BY perm.permission_name ASC, perm.state_desc ASC
UNION
--Extracting database level permissions
SELECT	getdate() AS ScriptDateTime,CASE WHEN perm.state <> 'W' THEN perm.state_desc ELSE 'GRANT' END
	+ SPACE(1) + perm.permission_name + SPACE(1)
	+ SPACE(1) + 'TO' + SPACE(1) + QUOTENAME(USER_NAME(usr.principal_id)) COLLATE database_default
	+ CASE WHEN perm.state <> 'W' THEN SPACE(0) ELSE SPACE(1) + 'WITH GRANT OPTION' END
	--+ CHAR(13)+CHAR(10)+'GO' 
	AS '--Database Level Permissions'
FROM	sys.database_permissions AS perm
	INNER JOIN
	sys.database_principals AS usr
	ON perm.grantee_principal_id = usr.principal_id
WHERE	perm.major_id = 0
AND (permission_name+USER_NAME(usr.principal_id) != 'CONNECTDBO')
--ORDER BY perm.permission_name ASC, perm.state_desc ASC
) AS UserScripts
ORDER BY Scripts