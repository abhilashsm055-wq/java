# Resets the database to the original demo data and deletes uploaded evidence files.
# Run this before your demo so you start from a clean state. MySQL must be running.
$root = $PSScriptRoot
Get-Content (Join-Path $root "database\schema.sql") -Raw |
    & "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root --host=127.0.0.1
Get-ChildItem (Join-Path $root "evidence-storage") -File -Exclude ".gitkeep" | Remove-Item -Force
Write-Host "Demo data reset. Evidence storage emptied." -ForegroundColor Green
