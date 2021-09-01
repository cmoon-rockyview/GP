
	/************************************************************************************************
	*
	*	Purpose:	To capture all the SQL Server logins with the binary password regardless of SQL version.  
	*				Script is compatiable with SQL 7 / 2000 / 2005/ 2008 / 2008R2 / 2012. 
	*				Need to save the results to a text file and run within a new query window.
	*
	*	Created Date:	Inital - 01/13/2006
	*
	*	Revsions:	01/15/2006 - Made some formatting changes to the output text.
	*			01/16/2006 - Made syntax change to account for Binary version of SQL Server.
	*			01/16/2006 - Change version SQL version check because of syntax differences between SQL 2000 and 2005 with @@version.
	*			04/10/2007 - Made change to deal with user names that begin with numbers instead of characters.
	*           11/14/2008 - Made syntax change to update for SQL 2008
        *           08/26/2010 - Made syntax change to update for SQL 2008 R2    
	*			12/20/2012 - Made syntax change to update for SQL 2012
	*			05/02/2014 - Changed version number check to handle SQL 2012 SP1 (and all future versions)
	*
	************************************************************************************************/

	USE master
	GO
	IF OBJECT_ID ('sp_hexadecimal') IS NOT NULL
	  DROP PROCEDURE sp_hexadecimal
	GO
	CREATE PROCEDURE sp_hexadecimal
		@binvalue varbinary(256),
		@hexvalue varchar(256) OUTPUT
	AS
	DECLARE @charvalue varchar(256)
	DECLARE @i int
	DECLARE @length int
	DECLARE @hexstring char(16)
	SELECT @charvalue = '0x'
	SELECT @i = 1
	SELECT @length = DATALENGTH (@binvalue)
	SELECT @hexstring = '0123456789ABCDEF'
	WHILE (@i <= @length)
	BEGIN
	  DECLARE @tempint int
	  DECLARE @firstint int
	  DECLARE @secondint int
	  SELECT @tempint = CONVERT(int, SUBSTRING(@binvalue,@i,1))
	  SELECT @firstint = FLOOR(@tempint/16)
	  SELECT @secondint = @tempint - (@firstint*16)
	  SELECT @charvalue = @charvalue +
		SUBSTRING(@hexstring, @firstint+1, 1) +
		SUBSTRING(@hexstring, @secondint+1, 1)
	  SELECT @i = @i + 1
	END
	SELECT @hexvalue = @charvalue
	GO

	IF OBJECT_ID ('sp_help_revlogin') IS NOT NULL
	  DROP PROCEDURE sp_help_revlogin
	GO
	CREATE PROCEDURE sp_help_revlogin @login_name sysname = NULL AS
	DECLARE @name    sysname
	DECLARE @xstatus int
	DECLARE @binpwd  varbinary (256)
	DECLARE @txtpwd  sysname
	DECLARE @tmpstr  varchar (256)
	DECLARE @SID_varbinary varbinary(85)
	DECLARE @SID_string varchar(256)

	IF (@login_name IS NULL)
	  DECLARE login_curs CURSOR FOR
		SELECT sid, name, xstatus, password FROM master..sysxlogins
		WHERE srvid IS NULL AND name <> 'sa'
	ELSE
	  DECLARE login_curs CURSOR FOR
		SELECT sid, name, xstatus, password FROM master..sysxlogins
		WHERE srvid IS NULL AND name = @login_name
	OPEN login_curs
	FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @xstatus, @binpwd
	IF (@@fetch_status = -1)
	BEGIN
	  PRINT 'No login(s) found.'
	  CLOSE login_curs
	  DEALLOCATE login_curs
	  RETURN -1
	END
	SET @tmpstr = '/* sp_help_revlogin script '
	PRINT @tmpstr
	SET @tmpstr = '** Generated '
	  + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
	PRINT @tmpstr
	PRINT ''
	PRINT 'DECLARE @pwd sysname'
	WHILE (@@fetch_status <> -1)
	BEGIN
	  IF (@@fetch_status <> -2)
	  BEGIN
		PRINT ''
		SET @tmpstr = '-- Login: ' + @name
		PRINT @tmpstr
		IF (@xstatus & 4) = 4
		BEGIN -- NT authenticated account/group
		  IF (@xstatus & 1) = 1
		  BEGIN -- NT login is denied access
			SET @tmpstr = 'EXEC master..sp_denylogin ''' + @name + ''''
			PRINT @tmpstr
		  END
		  ELSE BEGIN -- NT login has access
			SET @tmpstr = 'EXEC master..sp_grantlogin ''' + @name + ''''
			PRINT @tmpstr
		  END
		END
		ELSE BEGIN -- SQL Server authentication
		  IF (@binpwd IS NOT NULL)
		  BEGIN -- Non-null password
			EXEC sp_hexadecimal @binpwd, @txtpwd OUT
			IF (@xstatus & 2048) = 2048
			  SET @tmpstr = 'SET @pwd = CONVERT (varchar(256), ' + @txtpwd + ')'
			ELSE
			  SET @tmpstr = 'SET @pwd = CONVERT (varbinary(256), ' + @txtpwd + ')'
			PRINT @tmpstr
		EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
			SET @tmpstr = 'EXEC master..sp_addlogin ''' + @name + ''
			  + ''', @pwd, @sid = ' + @SID_string + ', @encryptopt = '
		  END
		  ELSE BEGIN
			-- Null password
		EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
			SET @tmpstr = 'EXEC master..sp_addlogin ''' + @name + ''
			  + ''', NULL, @sid = ' + @SID_string + ', @encryptopt = '
		  END
		  IF (@xstatus & 2048) = 2048
			-- login upgraded from 6.5
			SET @tmpstr = @tmpstr + '''skip_encryption_old'''
		  ELSE
			SET @tmpstr = @tmpstr + '''skip_encryption'''
		  PRINT @tmpstr
		END
	  END
	  FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @xstatus, @binpwd
	  END
	CLOSE login_curs
	DEALLOCATE login_curs
	RETURN 0
	GO

	IF OBJECT_ID ('seeMigrateSQLLogins') IS NOT NULL
	  DROP PROCEDURE seeMigrateSQLLogins
	GO
	create procedure seeMigrateSQLLogins @login_name sysname = NULL
	as
	DECLARE @name sysname
	DECLARE @type varchar (1)
	DECLARE @hasaccess int
	DECLARE @denylogin int
	DECLARE @is_disabled int
	DECLARE @PWD_varbinary  varbinary (256)
	DECLARE @PWD_string  varchar (514)
	DECLARE @SID_varbinary varbinary (85)
	DECLARE @SID_string varchar (514)
	DECLARE @tmpstr  varchar (1024)
	DECLARE @is_policy_checked varchar (3)
	DECLARE @is_expiration_checked varchar (3)

	DECLARE @defaultdb sysname
 
	IF (@login_name IS NULL)
	  DECLARE login_curs CURSOR FOR

		  SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name, l.hasaccess, l.denylogin FROM 
	sys.server_principals p LEFT JOIN sys.syslogins l
		  ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name <> 'sa'
	ELSE
	  DECLARE login_curs CURSOR FOR


		  SELECT p.sid, p.name, p.type, p.is_disabled, p.default_database_name, l.hasaccess, l.denylogin FROM 
	sys.server_principals p LEFT JOIN sys.syslogins l
		  ON ( l.name = p.name ) WHERE p.type IN ( 'S', 'G', 'U' ) AND p.name = @login_name
	OPEN login_curs

	FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
	IF (@@fetch_status = -1)
	BEGIN
	  PRINT 'No login(s) found.'
	  CLOSE login_curs
	  DEALLOCATE login_curs
	  RETURN -1
	END
	SET @tmpstr = '/* sp_help_revlogin script '
	PRINT @tmpstr
	SET @tmpstr = '** Generated ' + CONVERT (varchar, GETDATE()) + ' on ' + @@SERVERNAME + ' */'
	PRINT @tmpstr
	PRINT ''
	WHILE (@@fetch_status <> -1)
	BEGIN
	  IF (@@fetch_status <> -2)
	  BEGIN
		PRINT ''
		SET @tmpstr = '-- Login: ' + @name
		PRINT @tmpstr
		IF (@type IN ( 'G', 'U'))
		BEGIN -- NT authenticated account/group

		  SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + ']'
		END
		ELSE BEGIN -- SQL Server authentication
			-- obtain password and sid
				SET @PWD_varbinary = CAST( LOGINPROPERTY( @name, 'PasswordHash' ) AS varbinary (256) )
			EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT
			EXEC sp_hexadecimal @SID_varbinary,@SID_string OUT
 
			-- obtain password policy state
			SELECT @is_policy_checked = CASE is_policy_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
			SELECT @is_expiration_checked = CASE is_expiration_checked WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE name = @name
 
				SET @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'

			IF ( @is_policy_checked IS NOT NULL )
			BEGIN
			  SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked
			END
			IF ( @is_expiration_checked IS NOT NULL )
			BEGIN
			  SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked
			END
		END
		IF (@denylogin = 1)
		BEGIN -- login is denied access
		  SET @tmpstr = @tmpstr + '; DENY CONNECT SQL TO ' + QUOTENAME( @name )
		END
		ELSE IF (@hasaccess = 0)
		BEGIN -- login exists but does not have access
		  SET @tmpstr = @tmpstr + '; REVOKE CONNECT SQL TO ' + QUOTENAME( @name )
		END
		IF (@is_disabled = 1)
		BEGIN -- login is disabled
		  SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME( @name ) + ' DISABLE'
		END
		PRINT @tmpstr
	  END

	  FETCH NEXT FROM login_curs INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb, @hasaccess, @denylogin
	   END
	CLOSE login_curs
	DEALLOCATE login_curs
	RETURN 0
	GO

	if cast(ltrim(substring(@@version, patindex('%[0-9].[0-9]%', @@version)-1,4)) as decimal(4,2)) >= 9.0
		Begin
			exec seeMigrateSQLLogins
		End
	Else
		begin
			exec sp_help_revlogin
		End

	IF OBJECT_ID ('sp_hexadecimal') IS NOT NULL
	  DROP PROCEDURE sp_hexadecimal
	GO
	IF OBJECT_ID ('sp_help_revlogin') IS NOT NULL
	  DROP PROCEDURE sp_help_revlogin
	GO
	IF OBJECT_ID ('seeMigrateSQLLogins') IS NOT NULL
	  DROP PROCEDURE seeMigrateSQLLogins
	GO
/* End Script */
