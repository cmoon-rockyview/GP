USE [PAFD]
GO

/****** Object:  View [RV].[VW_ADUsers]    Script Date: 3/26/2020 3:53:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







--http://stackoverflow.com/questions/8594775/error-cannot-fetch-a-row-from-ole-db-provider-adsdsoobject-for-linked-server

--http://www.kouti.com/tables/userattributes.htm
ALTER VIEW [RV].[VW_ADUsers]
AS


--https://stackoverflow.com/questions/1324361/sql-query-for-disabled-active-directory-accounts

-- Last Logon time to date time format 
-- https://www.experts-exchange.com/articles/811/Converting-Active-Directory-Timestamps-in-Microsoft-SQL-Server.html
With CTE
as
(
SELECT top 901 samaccountname AS Account
		,ISNULL(givenName, '''') AS FirstName
		, ISNULL(SN, '''') AS LastName
		, ISNULL(DisplayName, '''') AS DisplayName
		, ISNULL(Title, '''') AS Title
		,ISNULL(department, '''') AS Department 
		,ISNULL(mail,'''') AS EMail		
		,telephoneNumber AS Telephone
		,userPrincipalName
		,createTimeStamp
		,whenCreated
		,whenChanged
		,physicalDeliveryOfficeName AS Location
		,DistinguishedName
		

	  ,lastLogon AS LastLogOn
	  --, ISNUMERIC(lastLogOn) as LastLogOnDate
	    , IIF( IsNumeric( lastLogOn) = 1 and convert(numeric(38,1), lastLogOn) > 0.0  ,
		
		  Convert( DateTime, ( convert( Numeric(38,1) , lastlogon) / 864000000000.0 ) - 109207 , 103) 
		  , null ) LastLogOnDate
	  
	  --,convert(dateTime, LastLogon, 103) as test
	  ,homeDrive as HomeDir
	  ,homeDirectory HomeDirectory     
	  ,Rtrim(Substring(DistinguishedName, 
	         charIndex(',',DistinguishedName) + 1 ,
			 len(DistinguishedName) - charIndex(',',DistinguishedName)   ) ) OrgUnit
      ,ScriptPath
	  ,Manager
	  ,substring(Manager, charindex('=', manager) + 1 ,
	            charindex(',OU', manager) - 4 )   ReportsToCN
	
			
	
FROM OPENQUERY(ADSI, 
'SELECT SamAccountName, givenName, SN, DisplayName, Title , department,   mail, telephoneNumber, userPrincipalName ,employeeID
     , createTimeStamp, whenCreated,whenChanged, physicalDeliveryOfficeName , DistinguishedName ,lastLogon
	 , homeDrive, homeDirectory , scriptPath, Manager
FROM ''LDAP://DC=mdrockyview,DC=ab,DC=ca'' 
WHERE objectClass = ''User'' and  objectCategory = ''Person''
	  and  mail = ''*@rockyview.ca''  and (SN = ''*'' or givenName = ''*'')') AD
)

select *
from CTE
where len(Title) > 3 AND (LastLogOn is not null or  Telephone is not null)

--Show only Active Users
-- ''userAccountControl:1.2.840.113556.1.4.803:''<>2 
GO


--864000000000