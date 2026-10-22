# Starts Tomcat in this window. Press Ctrl+C to stop.
$root = $PSScriptRoot
if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
}
$env:CATALINA_HOME = Join-Path $root "tools\apache-tomcat-10.1.60"
Write-Host "Open http://localhost:8080/forensics/  (Ctrl+C to stop)" -ForegroundColor Green
& (Join-Path $env:CATALINA_HOME "bin\catalina.bat") run
