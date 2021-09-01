USE [PAFD]
GO
/****** Object:  StoredProcedure [dbo].[Get_ADGroups_ForUser]    Script Date: 1/29/2019 2:10:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [LookUp].[GetADGroupsForUser]
(
    @Username NVARCHAR(256) 
)
AS
BEGIN

    DECLARE @Query NVARCHAR(1024), @Path NVARCHAR(1024)

    -- Find the fully qualified CN e.g: CN=Beau Holland,OU=Users,OU=Australia,OU=NSO,OU=Company,DC=Domain,DC=local
    -- replace "LDAP://DC=Domain,DC=local" with your own domain
    SET @Query = '
        SELECT @Path = distinguishedName
        FROM OPENQUERY(ADSI, ''
            SELECT distinguishedName 
            FROM ''''LDAP://DC=mdrockyview,DC=ab,DC=ca''''
            WHERE 
                objectClass = ''''user'''' AND
                sAMAccountName = ''''' + @Username + '''''
        '')
    '
    EXEC SP_EXECUTESQL @Query, N'@Path NVARCHAR(1024) OUTPUT', @Path = @Path OUTPUT 

    -- get all groups for a user
    -- replace "LDAP://DC=Domain,DC=local" with your own domain
    SET @Query = '
        SELECT cn,AdsPath
        FROM OPENQUERY (ADSI, ''<LDAP://DC=mdrockyview,DC=ab,DC=ca>;(&(objectClass=group)(member:1.2.840.113556.1.4.1941:=' + @Path +'));cn, adspath;subtree'')'

    EXEC SP_EXECUTESQL @Query  

END
GO
