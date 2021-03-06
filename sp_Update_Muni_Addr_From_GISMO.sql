USE [MLIVE]
GO
/****** Object:  StoredProcedure [dbo].[sp_Update_Muni_Addr_From_GISMO]    Script Date: 9/24/2019 1:11:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER  PROCEDURE [dbo].[sp_Update_Muni_Addr_From_GISMO]
AS
    BEGIN

	--we are going to truncate all the data and then insert the addresses
	--	from NAMEADDRESS
	
        DECLARE @dMUNADDR1 CHAR(11) ,
				@dMUNADDR2 CHAR(11) ,
				@dMUNADDR3 CHAR(25)
        DECLARE @dMUNADDRINDEX INT

        DECLARE @I_sCompanyID SMALLINT
        DECLARE @I_iSQLSessionID INT
        DECLARE @O_mNoteIndex NUMERIC(19, 5)
        DECLARE @O_iErrorState INT


        SET @I_sCompanyID = 1
        SET @I_iSQLSessionID = 0

--FIND THE STREET NAMES THAT ARE MISSING FROM THE SF006 TABLE
--INSERT INTO SF007

        PRINT 'updating SF007'

        DECLARE _x CURSOR
        FOR
            SELECT DISTINCT
                    UPPER(SUBSTRING(ISNULL(vchRoad, ''), 1, 25)) AS vchRoad
            FROM    [SQL-DynamicsGPMuniAddressUpdate].NameAddress.dbo.GISMOMunicipalAddresses a
			-- 'Not in' often gives inaccurate result. Needs to change it to 'Not Exists'
			-- GIS Dept changes existing address quite often. In this case duplicate addresses are inserted.
            WHERE   UPPER(SUBSTRING(vchRoad, 1, 25)) NOT IN ( SELECT
                                                              UPPER(dMUNADDR3)
                                                              FROM
                                                              SF007 )
            ORDER BY vchRoad


        OPEN _x

-- Perform the first fetch and store the values in variables.
-- Note: The variables are in the same order as the columns
-- in the SELECT statement. 

        FETCH NEXT FROM _x
INTO @dMUNADDR3

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
        WHILE @@FETCH_STATUS = 0
            BEGIN

	
                EXEC [DYNAMICS].[dbo].[smGetNextNoteIndex] @I_sCompanyID,
                    @I_iSQLSessionID, @O_mNoteIndex OUTPUT,
                    @O_iErrorState OUTPUT 

					--NoteIndex is assigned by Dynamcis.dbo.smGetNextNoteIndex
                INSERT  INTO SF007
                        ( dMUNADDR3, NOTEINDX )
                VALUES  ( @dMUNADDR3, @O_mNoteIndex )


   -- This is executed as long as the previous fetch succeeds.
                FETCH NEXT FROM _x
INTO @dMUNADDR3
            END

        CLOSE _x
        DEALLOCATE _x

        PRINT 'done updating SF007'


-----------------------------------------------------------
-----------------------------------------------------------

-----------------------------------------------------------

-----------------------------------------------------------
-----------------------------------------------------------

        PRINT 'updating SF006'

        DECLARE _c CURSOR
        FOR
            SELECT DISTINCT
                    UPPER(ISNULL(vchUnitBay, '')) AS vchUnitBay ,
                    ISNULL(intHouseNum, 0) AS intHouseNum ,
                    UPPER(SUBSTRING(ISNULL(vchRoad, ''), 1, 25)) AS vchRoad
            FROM    [SQL-DynamicsGPMuniAddressUpdate].NameAddress.dbo.GISMOMunicipalAddresses t
	        WHERE   intHouseNum NOT IN (
                    SELECT  dMUNADDR2
                    FROM    SF006 b
                    WHERE   UPPER(ISNULL(t.vchUnitBay, '')) = dMUNADDR1
                            AND
			-- Date: Aug.08/2007  Modified By: Cynthia P
			-- Checking for if NULL replace with a blank
                            UPPER(SUBSTRING(ISNULL(vchRoad, ''), 1, 25)) = dMUNADDR3 --UPPER(SUBSTRING(t.vchRoad,1,25)) = dMUNADDR3
	)
                    AND UPPER(ISNULL(vchUnitBay, '')) NOT IN (
                    SELECT  dMUNADDR1
                    FROM    SF006 b
                    WHERE   t.intHouseNum = dMUNADDR2
                            AND
			-- Date: Aug.08/2007  Modified By: Cynthia P
			-- Checking for if NULL replace with a blank
                            UPPER(SUBSTRING(ISNULL(vchRoad, ''), 1, 25)) = dMUNADDR3 --UPPER(SUBSTRING(t.vchRoad,1,25)) = dMUNADDR3
	)
                    AND UPPER(SUBSTRING(vchRoad, 1, 25)) NOT IN (
                    SELECT  dMUNADDR3
                    FROM    SF006 b
                    WHERE   UPPER(ISNULL(t.vchUnitBay, '')) = dMUNADDR1
                            AND t.intHouseNum = dMUNADDR2 )
            ORDER BY vchROAD ,
                    intHouseNum ,
                    vchUnitBay



        OPEN _c

-- Perform the first fetch and store the values in variables.
-- Note: The variables are in the same order as the columns
-- in the SELECT statement. 

        FETCH NEXT FROM _c
INTO @dMUNADDR1, @dMUNADDR2, @dMUNADDR3

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
        WHILE @@FETCH_STATUS = 0
            BEGIN

	
                EXEC [DYNAMICS].[dbo].[smGetNextNoteIndex] @I_sCompanyID,
                    @I_iSQLSessionID, @O_mNoteIndex OUTPUT,
                    @O_iErrorState OUTPUT 



                SELECT  @dMUNADDRINDEX = MAX(dMUNADDRINDEX + 1)
                FROM    SF006

                INSERT  INTO SF006
                        ( dMUNADDR1 ,
                          dMUNADDR2 ,
                          dMUNADDR3 ,
                          dMUNADDRINDEX ,
                          dUTROUTE ,
                          dROUTESEQNMBR ,
                          dUTCLASSID ,
                          NOTEINDX
                        )
                VALUES  ( @dMUNADDR1 ,
                          @dMUNADDR2 ,
                          @dMUNADDR3 ,
                          @dMUNADDRINDEX ,
                          '' ,
                          0 ,
                          '' ,
                          @O_mNoteIndex
                        )


   -- This is executed as long as the previous fetch succeeds.
                FETCH NEXT FROM _c
INTO @dMUNADDR1, @dMUNADDR2, @dMUNADDR3
            END

        CLOSE _c
        DEALLOCATE _c

        PRINT 'done updating SF006'


-----------------------------------------------------------

        TRUNCATE TABLE PT003

        INSERT  INTO PT003
                SELECT DISTINCT
                        SUBSTRING(vchRoll, 1, 15) AS vchRoll ,
                        UPPER(SUBSTRING(ISNULL(vchRoad, 0), 1, 25)) AS vchRoad ,
                        CAST(ISNULL(intHouseNum, 0) AS CHAR(11)) AS intHouseNum ,
                        UPPER(ISNULL(vchUnitBay, '')) AS vchUnitBay
                FROM    [SQL-DynamicsGPMuniAddressUpdate].NameAddress.dbo.GISMOMunicipalAddresses
	-- Date: Aug.08/2007  Modified By: Cynthia P
	-- Tempary workaround for eliminating Roll number nulls from the table
                WHERE   SUBSTRING(vchRoll, 1, 15) IS NOT NULL
		
		
        PRINT 'truncated and repopulated PT003'
    END
