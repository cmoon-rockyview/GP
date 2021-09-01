Alter View  LookUp.VW_PositionEmpAD

as

select
P.LoginName
,P.EmpNo
,A.HomeDir
,A.createTimeStamp
,A.OrgUnit
,Rtrim(Substring(A.Manager, 
	         charIndex(',',A.Manager) + 1 ,
			 len(A.Manager) - charIndex(',',A.Manager)   ) ) ReportsToOU
,P.PositionCode
,P.PositionDesc
,P.JobCode
,P.Locn
,P.LocnDesc
,P.ReportsToPosition
,P.ReportsToPositionDesc
from LookUp.PositionLogin P
Inner Join RV.VW_ADUsers A
on P.LoginName = A.Account





    