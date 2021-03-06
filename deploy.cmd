:: @if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 1.0.17
:: ----------------------

:: Prerequisites
:: -------------
where node
:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)
goto Deployment

:: Utility Functions
:: -----------------

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

:Deployment
echo Handling node.js deployment.

:: 1. KuduSync
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
  IF !ERRORLEVEL! NEQ 0 goto error
)

SET NPM_CMD=npm
SET NODE_EXE=node

:: 3. Install npm packages
IF EXIST "%DEPLOYMENT_TARGET%\package.json" (
  pushd "%DEPLOYMENT_TARGET%"
  echo Running npm install
  call :ExecuteCmd !NPM_CMD! config set openssl-root "%DEPLOYMENT_TARGET%\openssl" -g
  call :ExecuteCmd !NPM_CMD! config set scripts-prepend-node-path true
  call :ExecuteCmd !NPM_CMD! config set audit false
  call :ExecuteCmd !NPM_CMD! config set loglevel silent
  call :ExecuteCmd !NPM_CMD! install --production --no-package-lock
  call :ExecuteCmd !NPM_CMD! prune
  IF !ERRORLEVEL! NEQ 0 goto error
  popd
)

:: Bugfix - recompile node-sass
:: See https://github.com/pnp/generator-teams/issues/79 and https://stackoverflow.com/questions/41874420/express-app-with-node-sass-on-azure-app-service
:: IF EXIST "%DEPLOYMENT_SOURCE%\package.json" (
::  echo Rebuilding node-sass
::  pushd "%DEPLOYMENT_SOURCE%"
::  call :ExecuteCmd !NPM_CMD! rebuild node-sass
::  IF !ERRORLEVEL! NEQ 0 goto error
::  popd
::)

:: 4. Handle database creation and migrations.
IF EXIST "%DEPLOYMENT_TARGET%\db.js" (
  pushd "%DEPLOYMENT_TARGET%"
  echo Checking database
  call :ExecuteCmd "!NODE_EXE!" db.js
  IF !ERRORLEVEL! NEQ 0 goto error
  popd
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
