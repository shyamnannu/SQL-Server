------------------------------------------------ 
-- Show historical deadlocks
------------------------------------------------
DECLARE @ring AS [xml];

SET @ring = (SELECT     cast(xet.[target_data] AS [xml])
                        FROM       sys.dm_xe_session_targets xet
                        INNER JOIN sys.dm_xe_sessions xe
                                        ON xe.[address] = xet.[event_session_address]
                        WHERE      xe.[name] = 'system_health');

SELECT      ''                                                                                                          AS 'DEADLOCKS',
                        row_number()
                                OVER (
                                        ORDER BY syshealth.xevent.value( '(@timestamp)', 'DATETIME'))           AS 'Sequence',
                        syshealth.xevent.value('(@timestamp)',
                                                                   'DATETIME')                                    AS 'Deadlock time',
                        --SysHealth.XEvent.query('.') AS [DeadlockEvent],

                        cast(syshealth.xevent.value('data[1]',
                                                                                'NVARCHAR(MAX)') AS xml)         AS 'Deadlock graph'
--SysHealth.XEvent.value('data[1]','NVARCHAR(MAX)') AS DeadlockGraph
FROM        (SELECT @ring AS ring) AS buffer
CROSS apply ring.nodes ('//RingBufferTarget/event') AS syshealth (xevent)
WHERE       syshealth.xevent.value('(@name)[1]',
                                                                   'varchar (100)') = 'xml_deadlock_report'
ORDER       BY [deadlock time] DESC;
