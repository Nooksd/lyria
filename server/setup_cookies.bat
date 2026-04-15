@echo off
echo ============================================
echo   YouTube Cookie Setup for Lyria Import
echo ============================================
echo.
echo This script exports YouTube cookies from Chrome
echo so that the Spotify import can download from YouTube.
echo.
echo IMPORTANT: You MUST close ALL Chrome windows first!
echo.
pause

echo.
echo Exporting cookies from Chrome...
yt-dlp --cookies-from-browser chrome --cookies cookies.txt "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --skip-download --no-warnings 2>nul

if exist cookies.txt (
    echo.
    echo SUCCESS! cookies.txt created.
    echo The Spotify import should now work.
    echo.
    echo You can reopen Chrome now.
) else (
    echo.
    echo FAILED to export cookies.
    echo Make sure Chrome is completely closed and try again.
    echo.
    echo Alternative: Install the "Get cookies.txt LOCALLY" Chrome extension,
    echo go to youtube.com, click the extension, and save the file as
    echo "cookies.txt" in the server folder.
)
echo.
pause
