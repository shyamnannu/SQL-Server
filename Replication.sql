DECLARE @xact_seqno VARBINARY(16)
DECLARE @xact_seqno_str NCHAR(22)
SET @xact_seqno = 0x0000279A000002CE0032
SET @xact_seqno_str = MASTER.dbo.fn_varbintohexstr(@xact_seqno)

EXEC
sys.sp_browsereplcmds
	@xact_seqno_start = @xact_seqno_str
GO
