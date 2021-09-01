
--Initialize ID
Update GDB.ParcelInfo.RV.CurrMunAddresses set SF007 = S.DEX_ROW_ID
from GDB.ParcelInfo.RV.CurrMunAddresses G 
inner Join dbo.SF007 S
on Replace(G.vchRoad, ' ', '') = Replace(S.dMUNADDR3, ' ', '')


--Initialize OBJECTID
Update SF006 set dMUNADDRINDEX = G.OBJECTID
from SF006 S 
inner Join GDB.parcelInfo.RV.CurrMunAddresses G
on replace( (rtrim(S.dMUNADDR1)+ rtrim(S.dMUNADDR2)+ rtrim(S.dMUNADDR3) )  , ' ', '') = replace(G.vchAddress, ' ','')