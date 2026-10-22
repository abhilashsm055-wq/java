# Starts the project's own MySQL server (no Windows service / admin rights needed).
# First run: creates the database files in mysql-data\ and loads database\schema.sql.
$root  = $PSScriptRoot
$bin   = "C:\Program Files\MySQL\MySQL Server 8.4\bin"
$ini   = Join-Path $root "database\my.ini"
$data  = Join-Path $root "mysql-data"

if (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "MySQL is already running on port 3306." -ForegroundColor Yellow
    return
}

$firstRun = -not (Test-Path $data)
if ($firstRun) {
    Write-Host "Initialising MySQL data folder (first run only)..."
    # --initialize-insecure: root has no password, but the server only listens on 127.0.0.1
    & "$bin\mysqld.exe" --defaults-file="$ini" --initialize-insecure --console
}

Write-Host "Starting MySQL on 127.0.0.1:3306 ..."
Start-Process -FilePath "$bin\mysqld.exe" -ArgumentList "--defaults-file=`"$ini`"" -WindowStyle Hidden

# wait until the server accepts connections
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    & "$bin\mysqladmin.exe" -u root --host=127.0.0.1 ping 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
}

if ($firstRun) {
    Write-Host "Loading database\schema.sql ..."
    Get-Content (Join-Path $root "database\schema.sql") -Raw | & "$bin\mysql.exe" -u root --host=127.0.0.1
}
Write-Host "MySQL is ready." -ForegroundColor Green
