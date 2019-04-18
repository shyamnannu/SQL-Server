SELECT 

cpu_count, 

hyperthread_ratio, 

cpu_count /hyperthread_ratio as [Physical CPUs] 

FROM sys.dm_os_sys_info