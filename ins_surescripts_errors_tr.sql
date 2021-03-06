
-- =============================================
-- Author:		Kevin Foster
-- Create date: 03/22/2012
-- Description:	Basic database trigger that will
-- fire whenever a new erx error is returned by
-- surescripts.  The trigger sends an alert to 
-- the development team to take action to 
-- re-enroll the provider.
--
-- 2016-03-25 - kf - Added filter to suppress  
--   test patients and erx errors for duplicate
--   transmissions.
-- =============================================
CREATE TRIGGER [dbo].[ins_surescripts_errors_tr]
ON [dbo].[surescripts_errors]
AFTER INSERT--, UPDATE, DELETE 
AS
/***********Begin EMail Alert***************/
	DECLARE @sub VARCHAR(200)
	SELECT @sub='New eRx Error ('+db_name()+')'

	DECLARE @body VARCHAR(MAX)
	SELECT @body=
	'Practice:'+char(9)+practice_name+char(10)+
	'Provider:'+char(9)+prv.description+char(10)+
	'NPI #:'+char(9)+char(9)+prv.national_provider_id+char(10)+
	'SPI #:'+char(9)+char(9)+eprv.spi_nbr+char(10)+
	'Location:'+char(9)+l.location_name+char(10)+
	'Request:'+char(9)+emh.request_type+char(10)+
	--'Response:'+char(9)+emh.response_type+char(10)+
	'Pharmacy:'+char(9)+pa.destination+char(10)+
	'NCPDP ID:'+CHAR(9)+epx.ncpdp_id+CHAR(10)+
	'Error Msg:'+char(9)+ISNULL(se.description,'Unknown')+char(10)+
	'Med Name:'+char(9)+pm.medication_name+char(10)+
	'NDC ID:'+char(9)+pm.ndc_id+char(10)+
	'Med Prescribed:'+char(9)+CONVERT(VARCHAR(52),pm.create_timestamp)+char(10)+
	'Med Sent:'+char(9)+CONVERT(VARCHAR(52),emh.create_timestamp)+char(10)+
	'Error Returned:'+char(9)+CONVERT(VARCHAR(52),emh.modify_timestamp)+char(10)
	FROM INSERTED se 
	INNER JOIN erx_message_history emh WITH(NOLOCK) ON se.message_id=emh.message_id
	INNER JOIN practice pr WITH(NOLOCK) ON emh.practice_id=pr.practice_id
	INNER JOIN prescription_audit pa WITH(NOLOCK) ON pa.export_id=emh.message_id
	INNER JOIN patient_medication pm WITH(NOLOCK) ON pm.uniq_id=pa.medication_uniq_id
	INNER JOIN location_mstr l WITH(NOLOCK) ON pm.location_id=l.location_id
	INNER JOIN provider_mstr prv WITH(NOLOCK) ON prv.provider_id=pm.provider_id
	INNER JOIN erx_provider_mstr eprv WITH(NOLOCK) ON eprv.provider_id=prv.provider_id AND pm.practice_id=eprv.practice_id
	INNER JOIN person p WITH(NOLOCK) ON pm.person_id=p.person_id 
	INNER JOIN erx_pharmacy_xref epx WITH(NOLOCK) on emh.pharmacy_id=epx.pharmacy_id 
	WHERE response_type='ERROR'
	AND p.last_name NOT LIKE 'testt%'
	AND se.description NOT IN ('A duplicate message was found. Do not send identical prescriptions.', 'Message is a duplicate')

IF @@rowcount>0
BEGIN
	EXEC msdb.dbo.sp_send_dbmail 
		@profile_name='Services',
		@recipients='email1@example.com;email2@example.com;email3@example.com',
		@body=@body,
		@subject=@sub; 
END
/************End EMail Alert****************/
