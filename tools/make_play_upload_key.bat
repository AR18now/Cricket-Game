@echo off
rem Tap Tap Cricket - creates your Google Play UPLOAD KEY on this Windows PC.
rem The key never leaves your computer except when YOU paste it into GitHub Secrets.
rem Needs Java (free): "Eclipse Temurin JDK" from https://adoptium.net
setlocal enabledelayedexpansion
title Tap Tap Cricket - create Google Play upload key
set "OUT=%USERPROFILE%\Documents\TapTapCricket-upload-key"
set "KS=%OUT%\upload.keystore"

set "KT="
where keytool >nul 2>nul && set "KT=keytool"
if not defined KT for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk*" "%ProgramFiles%\Java\jdk*" "%ProgramFiles%\Microsoft\jdk*" "%ProgramFiles%\Zulu\zulu*") do if exist "%%~D\bin\keytool.exe" set "KT=%%~D\bin\keytool.exe"
if not defined KT if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe" set "KT=%ProgramFiles%\Android\Android Studio\jbr\bin\keytool.exe"
if not defined KT (
  echo.
  echo  Java was not found on this PC.
  echo  1. Open https://adoptium.net and install "Temurin JDK" ^(free, default options^).
  echo  2. Run this file again.
  echo.
  pause
  exit /b 1
)

if exist "%KS%" (
  echo.
  echo  You already have an upload key: %KS%
  echo  Keeping it ^(never make a second one for the same app^).
  goto :encode
)

mkdir "%OUT%" 2>nul
echo.
echo  ================================================================
echo   Creating your Google Play upload key
echo  ================================================================
echo   - Choose a STRONG password ^(at least 8 characters^) and WRITE IT DOWN.
echo     You type it twice; nothing shows on screen while you type.
echo   - Then answer the questions ^(your name, city, country code e.g. PK^).
echo     Press Enter to skip any you like, then type  yes  to confirm.
echo  ================================================================
echo.
"%KT%" -genkeypair -v -keystore "%KS%" -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 -validity 10000
if errorlevel 1 (
  echo.
  echo  Something went wrong - nothing was created. Run this file again.
  pause
  exit /b 1
)

:encode
certutil -f -encode "%KS%" "%OUT%\upload.keystore.base64.txt" >nul
echo.
echo  ================================================================
echo   DONE.  Folder: %OUT%
echo  ================================================================
echo   upload.keystore             = your key. BACK IT UP ^(USB drive + cloud^).
echo                                 Never share it, never put it in the repository.
echo   upload.keystore.base64.txt  = the same key as text, to paste into GitHub.
echo.
echo   Now add 3 secrets in GitHub: your repository - Settings -
echo   Secrets and variables - Actions - New repository secret:
echo     ANDROID_UPLOAD_KEYSTORE_BASE64    = whole content of upload.keystore.base64.txt
echo     ANDROID_UPLOAD_KEY_ALIAS          = upload
echo     ANDROID_UPLOAD_KEYSTORE_PASSWORD  = the password you chose
echo.
echo   You can delete upload.keystore.base64.txt after adding the secret.
echo  ================================================================
explorer "%OUT%"
pause
