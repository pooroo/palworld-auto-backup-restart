@echo off
setlocal

:: Set the paths and intervals
set "palworld_path=F:\SteamLibrary\steamapps\common\PalServer"
set "backup_path=F:\code\games\pal\backups"
set "rcon_path=\\TOWER\Movies\ARRCON\ARRCON.exe"  :: Add the path to your RCON tool here
set sevenzip_path="C:\Program Files\7-Zip\7z.exe" :: Add the path to your 7ZIP here
set interval=14400
set monitor_inv=10 :: Set check interval time here
set rcon_host=127.0.0.1
set rcon_port=25575
set rcon_password=your_password
:: Initial start time
set /a "start_time=%time:~0,2%*3600 + %time:~3,2%*60 + %time:~6,2%"
echo [%date% %time%] Starting server...

:monitorServer
:: Monitoring loop
:monitorLoop
call :checkRestartTime
:: Check if PalServer-Win64-Test-Cmd.exe is running
tasklist | findstr /i "PalServer-Win64-Test-Cmd" > NUL
if %errorlevel% neq 0 (
    echo [%date% %time%] PalServer-Win64-Test-Cmd.exe not running. Starting server...
    start "" "%palworld_path%\PalServer.exe" -EpicApp=PalServer -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
    :: Reset the start time
    set /a "start_time=%time:~0,2%*3600 + %time:~3,2%*60 + %time:~6,2%"
)
timeout /t %monitor_inv%
goto monitorLoop

:: Function to send RCON commands
:sendRcon
start "" "%rcon_path%" -H %rcon_host% -P %rcon_port% -p %rcon_password% %1
exit /b

:: Function to check if restart time has been reached
:checkRestartTime
call :getTimeSeconds current_time
set /a "elapsed_time=current_time - start_time"
if %elapsed_time% lss 0 set /a "elapsed_time=elapsed_time + 86400"
echo [%date% %time%] Elapsed time: %elapsed_time% seconds
if %elapsed_time% geq %interval% (
    echo [%date% %time%] Restart interval reached. Starting restart procedure...
    call :restartServer
)
exit /b

:: Function to get the current time in seconds
:getTimeSeconds
set "current_time=%time%"
:: Remove leading space if any (happens before 10:00 AM)
if "%current_time:~0,1%"==" " set "current_time=0%current_time:~1%"
:: Replace leading zero (if any) to avoid octal interpretation
set "hours=%current_time:~0,2%"
set "minutes=%current_time:~3,2%"
set "seconds=%current_time:~6,2%"
if "%hours:~0,1%"=="0" set /a "hours=1%hours%" - 100
if "%minutes:~0,1%"=="0" set /a "minutes=1%minutes%" - 100
if "%seconds:~0,1%"=="0" set /a "seconds=1%seconds%" - 100
set /a "%1=%hours%*3600 + %minutes%*60 + %seconds%"
exit /b

:: Restart server procedure
:restartServer
:: Server restart announcements and shutdown logic
echo [%date% %time%] Announcing server restart...
call :sendRcon "Broadcast ServerRestartIn5min."
timeout /t 120

:: Save the game state before shutting down
call :sendRcon "Broadcast Saving."
call :sendRcon "save"
call :sendRcon "Broadcast Saved."

call :sendRcon "Broadcast ServerRestartIn3min."
timeout /t 120

:: Backup logic just before shutdown
echo [%date% %time%] Backup server data...
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set datetime=%%a
set datestamp=%datetime:~0,8%
set timestamp=%datetime:~8,6%
set year=%datestamp:~0,4%
set month=%datestamp:~4,2%
set day=%datestamp:~6,2%
set hour=%timestamp:~0,2%
set minute=%timestamp:~2,2%
set second=%timestamp:~4,2%
set foldername=%year%-%month%-%day%_%hour%-%minute%-%second%
%sevenzip_path% a -tzip "%backup_path%\Backup_%foldername%.zip" "%palworld_path%\Pal\Saved\SaveGames\0"
echo Backup of %palworld_path%\Pal\Saved\SaveGames\0 completed at %backup_path%\Backup_%foldername%.zip

call :sendRcon "Broadcast ServerRestartIn1min."
timeout /t 60

:: Shutdown command
call :sendRcon "Broadcast ServerRestartIn1minLOGOUTNOW."
call :sendRcon "DoExit"

:: Reset start time
set /a "start_time=%time:~0,2%*3600 + %time:~3,2%*60 + %time:~6,2%"
goto monitorServer
