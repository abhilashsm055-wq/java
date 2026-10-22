# =====================================================================
#  build.ps1 - compiles the Java source and deploys the web app to Tomcat
#  Usage:  .\build.ps1
# =====================================================================
$ErrorActionPreference = "Stop"
$root    = $PSScriptRoot
$tomcat  = Join-Path $root "tools\apache-tomcat-10.1.60"
$web     = Join-Path $root "web"
$classes = Join-Path $web "WEB-INF\classes"
$weblib  = Join-Path $web "WEB-INF\lib"

if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName
}
$javac = Join-Path $env:JAVA_HOME "bin\javac.exe"

Write-Host "1/4  Cleaning old classes..."
if (Test-Path $classes) { Remove-Item $classes -Recurse -Force }
New-Item -ItemType Directory -Force $classes, $weblib | Out-Null

Write-Host "2/4  Compiling Java source..."
$sources = Get-ChildItem (Join-Path $root "src") -Recurse -Filter *.java | ForEach-Object { $_.FullName }
$cp = @((Join-Path $tomcat "lib\servlet-api.jar"), (Join-Path $tomcat "lib\jsp-api.jar"), (Join-Path $root "lib\*")) -join ";"
& $javac -encoding UTF-8 -Xlint:unchecked -d $classes -cp $cp @sources
if ($LASTEXITCODE -ne 0) { throw "Compilation failed" }

Write-Host "3/4  Copying libraries and config..."
Copy-Item (Join-Path $root "lib\*.jar") $weblib -Force
Copy-Item (Join-Path $root "config\db.properties") $classes -Force

Write-Host "4/4  Registering app with Tomcat (context: /forensics)..."
# Tomcat serves the web/ folder directly, so JSP edits show up on refresh without rebuilding.
$ctxDir = Join-Path $tomcat "conf\Catalina\localhost"
New-Item -ItemType Directory -Force $ctxDir | Out-Null
$docBase = $web.Replace([char]92, [char]47)
@"
<Context docBase="$docBase" reloadable="true" />
"@ | Set-Content (Join-Path $ctxDir "forensics.xml") -Encoding ASCII

Write-Host "Build OK. Start the server with .\run.ps1  ->  http://localhost:8080/forensics/" -ForegroundColor Green
