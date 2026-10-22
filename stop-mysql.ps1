# Cleanly shuts down the project's MySQL server.
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqladmin.exe" -u root --host=127.0.0.1 shutdown
Write-Host "MySQL stopped."
