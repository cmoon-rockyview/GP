USE [MDTST]
GO
/****** Object:  StoredProcedure [dbo].[spUpdateMunicipalAddress]    Script Date: 9/24/2019 1:03:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON

-- select * from GDB.ParcelInfo.RV.CurrMunAddresses
GO
ALTER PROCEDURE [dbo].[spUpdateMunicipalAddress]

AS
BEGIN
	
	--Merge SF007
	Merge dbo.SF007 as Target
		Using (select distinct SF007, vchRoad from GDB.ParcelInfo.RV.CurrMunAddresses) as Source
		on Target.DEX_ROW_ID = Source.[SF007]

		-- if unique Id mateched update address
		When Matched Then
		Update Set dMUNADDR3 = Left(Source.vchRoad, 25)

		--if unique id not exist in SF007, insert it
		When Not Matched By Target Then
		Insert (dMUNADDR3) 
		values(Left(Source.vchRoad, 25))

		--if unique id not exist in database, delete it
		WHEN NOT MATCHED BY SOURCE 
		THEN DELETE		;

		
		--  Update primary key of SF007 to RV.CurrMunAddress 
		Update GDB.ParcelInfo.RV.CurrMunAddresses set SF007 = S.DEX_ROW_ID
		from GDB.ParcelInfo.RV.CurrMunAddresses G 
		inner Join dbo.SF007 S
		on G.vchRoad = S.dMUNADDR3
		where G.SF007 is null
	;


	
	--Merge 006
	Merge dbo.SF006 as Target
		Using (select * from GDB.ParcelInfo.RV.CurrMunAddresses) as Source
		on Target.dMUNADDRINDEX = Source.OBJECTID

		When Matched Then
		Update set dMUNADDR1 = IsNull(vchUnitBay, ''), dMUNADDR2 = IsNull(intHouseNum, 0) , dMUNADDR3 = Left(vchRoad,25)

		When Not Matched by Target Then
		Insert ([dMUNADDR1], dMUNADDR2 , dMUNADDR3, dMunAddrIndex ) 
		values (IsNull(vchUnitBay, '') ,IsNull(intHouseNum, 0) ,Left( vchRoad, 25) ,  OBJECTID )

		WHEN NOT MATCHED BY SOURCE 
		THEN DELETE
	;



	-- Assign NoteIndex Number
	
   -- https://www.mssqltips.com/sqlservertip/1599/sql-server-cursor-example/

	DECLARE @O_mNoteIndex NUMERIC(19, 5)
    DECLARE @O_iErrorState INT
	Declare @NoteIndex numeric(19,5)
	Declare @dex_row_id int

	-- SF007
    declare db_cursor Cursor For select NOTEINDX , DEX_ROW_ID from SF007 where NOTEINDX = 0

	Open db_cursor
	Fetch Next From db_cursor Into @NoteIndex , @dex_row_id

	While @@FETCH_STATUS = 0
	Begin

		EXEC [DYNAMICS].[dbo].[smGetNextNoteIndex] 1,
                0 , @O_mNoteIndex OUTPUT,
                @O_iErrorState OUTPUT 

		Update dbo.SF007 set NOTEINDX = @O_mNoteIndex where DEX_ROW_ID = @dex_row_id

		Fetch Next From db_cursor into @NoteIndex , @dex_row_id
		

	End

	CLOSE db_cursor  
	DEALLOCATE db_cursor 


	-- SF006
    declare db_cursor Cursor For select NOTEINDX , DEX_ROW_ID from SF006 where NOTEINDX = 0

	Open db_cursor
	Fetch Next From db_cursor Into @NoteIndex , @dex_row_id

	While @@FETCH_STATUS = 0
	Begin

		EXEC [DYNAMICS].[dbo].[smGetNextNoteIndex] 1,
                0 , @O_mNoteIndex OUTPUT,
                @O_iErrorState OUTPUT 

		Update dbo.SF006 set NOTEINDX = @O_mNoteIndex where DEX_ROW_ID = @dex_row_id

		Fetch Next From db_cursor into @NoteIndex , @dex_row_id
		

	End

	CLOSE db_cursor  
	DEALLOCATE db_cursor 



	TRUNCATE TABLE PT003

    INSERT  INTO PT003
    SELECT DISTINCT
            SUBSTRING(IsNull(vchRoll,''), 1, 15) AS vchRoll ,
            UPPER(SUBSTRING(ISNULL(vchRoad, 0), 1, 25)) AS vchRoad ,
            CAST(ISNULL(intHouseNum, 0) AS CHAR(11)) AS intHouseNum ,
            UPPER(ISNULL(vchUnitBay, '')) AS vchUnitBay
    from GDB.ParcelInfo.RV.CurrMunAddresses




END
