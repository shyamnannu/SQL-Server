USE MP1
GO

SET NOCOUNT ON
DECLARE
@statistic_name SYSNAME,
@mod_counter INT,
@cmd NVARCHAR(500)


DECLARE Stat_cursor CURSOR FOR
SELECT name, modification_counter 
FROM sys.stats AS stat 
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE stat.object_id = object_id('mp1.AUSP')

OPEN Stat_cursor   
FETCH NEXT FROM Stat_cursor INTO @statistic_name,@mod_counter   

WHILE @@FETCH_STATUS = 0   
BEGIN
IF @mod_counter > 50000
BEGIN
SET @cmd= 'UPDATE STATISTICS mp1.AUSP ' + @statistic_name + ' WITH FULLSCAN'
EXEC (@cmd)
END
FETCH NEXT FROM Stat_cursor INTO @statistic_name,@mod_counter  
END   

CLOSE Stat_cursor   
DEALLOCATE Stat_cursor 