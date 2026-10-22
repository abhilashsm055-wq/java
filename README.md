# ForensiTrack: Digital Forensics Investigation System

Micro project (Java Enterprise). A web application for **ABC Cyber Forensics & Incident Response Center**
to manage investigation cases, upload digital evidence, verify its integrity with **SHA-256**, keep a
**chain of custody**, analyse logs, rebuild the incident **timeline**, record **findings** and generate **reports**.

**Tech:** Java 21 · Servlets · JSP + JSTL · JDBC · MySQL 8.4 · Apache Tomcat 10.1 · HTML/CSS/JS

---

## 0. First-time setup (after cloning from GitHub)

Tomcat and the database files are not stored in the repository. On a new computer:

1. Install **JDK 21** (`winget install EclipseAdoptium.Temurin.21.JDK`) and **MySQL Server 8.4** (`winget install Oracle.MySQL`).
2. Download [apache-tomcat-10.1.x-windows-x64.zip](https://tomcat.apache.org/download-10.cgi) and unzip it into `tools\`,
   so you have `tools\apache-tomcat-10.1.60\bin\...` (if your version differs, update the folder name in `build.ps1` and `run.ps1`).
3. If the project is not in `C:\Users\Lenovo\javamicroproject`, update the paths in `database\my.ini` and `config\db.properties`.
4. Continue with step 1 below. The first `start-mysql.ps1` run creates the database automatically.

## 1. Run it (every time)

Open PowerShell in this folder and run:

```powershell
.\start-mysql.ps1      # 1. start the database
.\build.ps1            # 2. compile Java + deploy (only needed after changing .java files)
.\run.ps1              # 3. start Tomcat - keep this window open
```

Open **http://localhost:8080/forensics/**

To stop: press `Ctrl+C` in the Tomcat window, then run `.\stop-mysql.ps1`.

> If PowerShell says "running scripts is disabled", run once:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## 2. Demo logins

| Username       | Password      | Role                  | Can do                                              |
|----------------|---------------|-----------------------|-----------------------------------------------------|
| `admin`        | `Admin@123`   | Administrator         | Everything, including assigning and **closing** cases |
| `investigator` | `Invest@123`  | Forensic Investigator | Create cases, upload evidence, record custody        |
| `analyst`      | `Analyst@123` | Analyst               | Log analysis, verify hashes, add findings (read-only cases) |

## 3. Suggested demo (5 minutes)

1. `.\reset-demo.ps1` beforehand for clean data.
2. Log in as **investigator** → Dashboard.
3. **Cases → New case** (or open *DF-2026-001*).
4. **Upload evidence** → choose `sample-evidence\hr_server_auth.log`. Point out the SHA-256 hash and the two automatic custody entries.
5. Click **Verify integrity now** → green *Verified*.
6. **Tamper test:** open `evidence-storage\` in Notepad, change one letter in the stored log file, save.
   Click **Verify** again → red *Evidence may have been modified*. (Undo your change and verify again to show it goes back to green.)
7. **Record custody action** → *Transferred* to Arjun Mehta.
8. **Analyse log** → keyword bar chart → tick some lines → **Add selected to timeline**.
9. **Timeline** → events from manual entries, log lines and custody, all in time order.
10. **Findings** → record a CRITICAL finding linked to the evidence.
11. **Reports → Investigation Summary** → *Print / Save as PDF*; show **Download CSV** for custody.
12. Log out → log in as **analyst** → show the upload button is gone (role-based access).
13. Toggle dark mode (moon icon, top right).

## 4. Folder structure

```
javamicroproject/
├── src/com/digitalforensics/     Java source (MVC)
│   ├── model/        entity classes + enums            (OOP)
│   ├── dao/          SQL with JDBC PreparedStatements  (JDBC)
│   ├── service/      business rules, hashing, analysis (threads, collections, files)
│   ├── controller/   Servlets - one per page           (Servlets)
│   ├── filter/       AuthFilter - login + CSRF check
│   ├── exception/    custom exceptions
│   └── util/         DBConnection, HashUtil, FileUtil, BackgroundExecutor, DateUtil
├── web/                          the web app Tomcat serves
│   ├── WEB-INF/jsp/  JSP pages (views)                 (JSP)
│   ├── WEB-INF/web.xml
│   ├── css/style.css · js/app.js
├── config/db.properties          database URL / user / password
├── database/schema.sql           7 tables + demo data  (MySQL)
├── database/my.ini               settings for the project's MySQL server
├── sample-evidence/              files to upload during the demo
├── evidence-storage/             uploaded evidence is saved here
├── lib/                          MySQL JDBC driver, JSTL jars
├── tools/apache-tomcat-10.1.60/  Tomcat (portable)
├── mysql-data/                   MySQL database files (created on first start)
└── build.ps1 · run.ps1 · start-mysql.ps1 · stop-mysql.ps1 · reset-demo.ps1
```

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| "The database is not reachable" | Run `.\start-mysql.ps1` |
| Port 8080 already in use | Another Tomcat is running. Close it, or change `port="8080"` in `tools\apache-tomcat-10.1.60\conf\server.xml` |
| Changed a `.java` file but nothing happened | Run `.\build.ps1` again (Tomcat reloads automatically) |
| Changed a `.jsp` / `.css` file | Just refresh the browser |
| Want a fresh start | `.\reset-demo.ps1` |

See **VIVA_NOTES.md** for how everything works and likely viva questions.
