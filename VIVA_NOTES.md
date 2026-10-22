# Viva Notes: Digital Forensics Investigation System

Read this file before the viva. Every answer points to the real file in the project so you can open it and show it.

---

## 1. Explain the project in 30 seconds

> "When a cyber incident happens, investigators collect digital evidence such as log files, screenshots and documents.
> That evidence is only useful in court if we can prove **nobody changed it** and **who handled it**.
> Our system, ForensiTrack, lets an investigator create a case, upload evidence, and the server immediately
> calculates a **SHA-256 hash**, a fingerprint of the file. Later we re-hash the file: if the hash is the same,
> the evidence is verified; if even one byte changed, the hash is completely different and we flag it.
> Every action is written to an append-only **chain of custody**. We can also scan logs for suspicious keywords,
> build a timeline, record findings and print reports. It's built with Servlets, JSP, JDBC and MySQL using MVC."

---

## 2. Architecture (MVC)

```
 Browser ──HTTP──▶ AuthFilter ──▶ Servlet (Controller) ──▶ Service ──▶ DAO ──JDBC──▶ MySQL
   ▲                 (login,        e.g. EvidenceServlet    business    SQL only
   │                  CSRF)                 │               rules
   │                                        ▼                 │
   └──────── HTML ◀── JSP (View) ◀── request attributes      └──▶ evidence-storage/ (files)
```

| Layer | Package | Job | Example |
|---|---|---|---|
| **Model** | `model` | Plain Java objects that hold data | `Evidence.java`, `Case.java` |
| **View** | `web/WEB-INF/jsp` | Show data as HTML, no logic | `evidence/view.jsp` |
| **Controller** | `controller` | Read request → call service → pick view | `EvidenceServlet.java` |
| Service | `service` | Rules: validation, roles, hashing | `EvidenceService.java` |
| DAO | `dao` | All SQL lives here | `EvidenceDAO.java` |

**Why MVC?** Each part has one job, so we can change the look (JSP) without touching SQL, or change the database without touching pages.

**Why are JSPs inside `WEB-INF`?** The browser cannot open anything inside WEB-INF directly (try `/forensics/WEB-INF/jsp/dashboard.jsp` → 404). So every page *must* go through a servlet, which checks login and loads data first.

### Example request: uploading evidence (walk through this in the viva)

1. Browser sends `POST /evidence` as `multipart/form-data` (needed to send a file).
2. `AuthFilter` checks the user is logged in and the CSRF token matches.
3. `EvidenceServlet.doPost()` reads the file with `req.getPart("file")`. `@MultipartConfig` makes this possible.
4. `EvidenceService.upload()`:
   - checks the role (`role.canUploadEvidence()`) → else `UnauthorizedAccessException`
   - checks the case exists and isn't closed → else `InvalidCaseException`
   - checks extension and size → else `InvalidEvidenceException`
   - saves the file to `evidence-storage/` with a random prefix (so names never clash)
   - `HashService.calculate()` runs SHA-256 **on a background thread** and waits for the `Future`
   - `EvidenceDAO.insert()` saves metadata + hash to MySQL
   - `CustodyDAO.insert()` twice: "Evidence Collected" and "Hash Generated"
5. The servlet redirects to `/evidence?id=5` (**Post/Redirect/Get**, so refreshing doesn't upload twice).
6. `evidence/view.jsp` shows the hash and custody list.

---

## 3. Where each Java module (syllabus) is used

| Module | Concept | Where in the code |
|---|---|---|
| **I: Fundamentals** | Strings, loops, conditions, arrays, validation | `CaseService.validate()`, `FileUtil.sanitize()`, loop reading lines in `AnalysisService.scan()`, `String[]` in `toCsvRow()` |
| **II: OOP** | Classes & objects | every file in `model/` |
| | Encapsulation | private fields + getters/setters in `Evidence.java` |
| | Inheritance | `BaseEntity` → `Evidence`, `Case`, `User`…; `BaseServlet` → all servlets; `BaseDAO` → all DAOs; `ForensicsException` → 4 custom exceptions |
| | Abstraction | `abstract class BaseEntity` with `abstract getDisplayCode()` |
| | Polymorphism | each entity overrides `getDisplayCode()` differently (`EV-0001`, `DF-2026-001`, `FND-3`); `ReportService.toCsv(List<? extends Reportable>)` works for 5 different classes |
| | Interfaces | `Reportable` (CSV rows), `Comparable<TimelineEvent>`, `RowMapper<T>` (functional interface) |
| | Enums with behaviour | `Role.canCloseCase()` etc. in `Role.java` |
| **III: Exceptions** | Custom exceptions | `exception/`: `InvalidEvidenceException`, `InvalidCaseException`, `EvidenceNotFoundException`, `UnauthorizedAccessException` |
| | try-with-resources | every JDBC call in `BaseDAO`, file reading in `HashUtil.sha256()` |
| | Checked vs unchecked | `ForensicsException` is checked (must handle); `DataAccessException` is unchecked (wraps `SQLException`) |
| **III: Multithreading** | Thread pool | `BackgroundExecutor`: `Executors.newFixedThreadPool(4)` |
| | Callable / Future / timeout | `HashService.calculate()` and `AnalysisService.analyze()`: `future.get(30, SECONDS)` |
| | Clean shutdown | `AppContextListener.contextDestroyed()` shuts the pool down |
| **III: File handling** | Upload & save | `Files.copy()` in `EvidenceService.upload()` |
| | Reading in chunks | `HashUtil.sha256(Path)`: 8 KB buffer, so large files don't fill memory |
| | Reading text line by line | `BufferedReader` in `AnalysisService.scan()` |
| | Writing CSV | `ReportService.toCsv()` + `ReportServlet` download |
| **IV: Collections** | `ArrayList`, `List` | all DAOs return `List<T>` |
| | `HashMap` / `LinkedHashMap` / `EnumMap` | keyword counts `LinkedHashMap<String,Integer>` + `merge()` in `AnalysisService`; `EnumMap<CaseStatus,Integer>` in `DashboardStats` |
| | `Set` (`LinkedHashSet`) | de-duplicated keywords in `AnalysisService.parseKeywords()` |
| | Sorting | `Collections.sort(events)` using `compareTo` in `TimelineService.build()` |
| | Lambdas & streams | `events.removeIf(e -> …)`, `Collectors.groupingBy(...)` in `TimelineService`; `.filter(Evidence::isTextReadable)` in `AnalysisServlet`; `UserDAO::map` method references |
| **V: JDBC** | `DriverManager`, `PreparedStatement`, `ResultSet`, generated keys | `DBConnection.java`, `BaseDAO.java` |
| **V: MySQL** | 7 tables, PK/FK, ENUM, indexes, JOINs | `database/schema.sql`, JOINs in `CaseDAO.SELECT` |
| **V: Servlets** | `doGet`/`doPost`, `@WebServlet`, sessions, redirect vs forward, filter, listener, multipart | `controller/`, `filter/AuthFilter.java` |
| **V: JSP** | EL `${}`, JSTL `<c:forEach>`, `<c:if>`, `<c:choose>`, `<c:out>`, static include | `web/WEB-INF/jsp/` |

> **Swing desktop app:** the syllabus also has Swing (Module IV). It's a separate deliverable and is **not** part of this website.
> Because all the logic is in `service/` and `dao/`, a Swing `JFrame` can reuse the same classes. That's a key benefit of the layered design.

---

## 4. Database (7 tables)

Ma'am reduced the scope, so the doc's 16 tables became 7:

| Table | Purpose | Key relationships |
|---|---|---|
| `users` | login accounts + role | |
| `cases` | investigations | `assigned_to`, `created_by` → users |
| `evidence` | file metadata + **original SHA-256** | `case_id` → cases |
| `hash_checks` | every verification result (history) | `evidence_id` → evidence |
| `chain_of_custody` | who did what, when (**append-only**) | `evidence_id` → evidence, `performed_by`/`handed_to` → users |
| `timeline_events` | manual / log / system events | `case_id` → cases |
| `findings` | conclusions with severity | `case_id` → cases, `evidence_id` → evidence (optional) |

- **Merged tables:** Roles/User_Roles became an `ENUM` column (each user has one role). Evidence_Types became an `ENUM`. Evidence_Analysis/Log_Records aren't stored, because analysis is recalculated from the file. Audit_Log/Login_Log were removed by ma'am (only `last_login` is kept).
- **Why is the file on disk and not in MySQL?** Databases are slow with big binary data (BLOBs). We store the file in a folder and keep its name + hash in MySQL. This matches the doc: "evidence files managed through secure file-handling".
- **Why a separate `forensics_app` MySQL user?** Least privilege. The app can only SELECT/INSERT/UPDATE/DELETE on its own database, and can't drop tables or read other databases.

---

## 5. Security features (examiners love these)

| Threat | Protection | File |
|---|---|---|
| Password theft from DB | Passwords stored as **SHA-256(salt + password)**, never plain text. The salt is random per user, so equal passwords get different hashes | `HashUtil.hashPassword()`, `AuthenticationService` |
| Guessing usernames | Same error message for wrong user and wrong password | `AuthenticationService.login()` |
| **SQL injection** | Only `PreparedStatement` with `?`, input never concatenated into SQL | `BaseDAO.prepare()` |
| **XSS** (script in input) | All user text printed with `<c:out>` / `fn:escapeXml`, which turns `<` into `&lt;` | every JSP |
| **CSRF** (fake form from another site) | Random token stored in the session and hidden in every form. The filter rejects POSTs without it (403) | `AuthFilter`, `LoginServlet` |
| Session fixation | Old session invalidated and a new one created at login | `LoginServlet.doPost()` |
| Not logged in | Filter redirects everything except `/login`, css, js | `AuthFilter` |
| Wrong role | Checked in the **service layer** (not only by hiding buttons), so even a hand-made request is refused | `Role.java`, each service |
| Path traversal (`..\..\file`) | Uploaded names are sanitised and prefixed with a random ID | `FileUtil.sanitize()` |
| Back button after logout | `Cache-Control: no-store` | `AuthFilter` |
| Excel formula injection in CSV | Cells starting with `= + - @` are prefixed with `'` | `ReportService.escape()` |
| Tampering with custody log | DAO has no update/delete methods for custody | `CustodyDAO` |

---

## 6. Likely viva questions and answers

**Q: What is SHA-256? Why not MD5?**
A cryptographic hash function that turns any input into a 256-bit (64 hex characters) value. It's one-way (you can't get the file back from the hash), and a tiny change gives a totally different hash (the avalanche effect). MD5 and SHA-1 are broken: people can create two different files with the same hash (collisions), so they're not trusted for evidence.

**Q: How does verification work?**
At upload we store the hash in `sha256_original`. When you click Verify, `EvidenceService.verify()` re-reads the file, hashes it again, and compares using `HashUtil.matches()`. Equal → VERIFIED; different → MODIFIED. The result goes into `hash_checks` and the chain of custody.

**Q: What is chain of custody?**
A chronological record of everyone who handled the evidence and what they did. Courts need it to trust that the evidence wasn't swapped or altered. Ours is append-only.

**Q: Difference between `forward` and `redirect`?**
`forward` happens inside the server: same request, and the URL doesn't change. We use it to show a JSP. `redirect` tells the browser to make a *new* request to another URL. We use it after every POST (Post/Redirect/Get) so a refresh doesn't resubmit the form.

**Q: What is a Servlet? Its life cycle?**
A Java class that handles HTTP requests. Life cycle: `init()` once → `service()` for every request, which calls `doGet`/`doPost` → `destroy()` when Tomcat stops. Tomcat creates one instance and uses many threads, which is why our servlets keep no per-user data in fields.

**Q: What does JSP turn into?**
Tomcat translates each JSP into a servlet (Java class), compiles it, and runs it. You can see these in `tools/apache-tomcat-10.1.60/work/`.

**Q: What is a Filter? Listener?**
A Filter runs before or after servlets on matching URLs. We use `AuthFilter` on `/*` for login and CSRF. A Listener reacts to app events. `AppContextListener` runs when the app starts and stops, and shuts down the thread pool.

**Q: Why use a thread pool for hashing?**
Hashing a big file takes time. The pool (4 threads) runs it as a `Callable`, and we wait with a **timeout** so a huge or stuck file can't hang the request forever. A pool re-uses threads instead of creating a new one each time.

**Q: What is a session? How does login work?**
HTTP is stateless. Tomcat gives the browser a `JSESSIONID` cookie and keeps a `HttpSession` object on the server. After a correct password we store the `User` object in the session. `AuthFilter` checks it on every request. Sessions time out after 30 min (`web.xml`).

**Q: What is PreparedStatement and why use it?**
A pre-compiled SQL statement with `?` placeholders. Values are sent separately, so input like `' OR 1=1 --` is treated as plain text, not SQL. It prevents SQL injection and is also faster when repeated.

**Q: Explain your custom exceptions.**
`ForensicsException` (checked) is the parent. Children are `InvalidCaseException`, `InvalidEvidenceException`, `EvidenceNotFoundException` and `UnauthorizedAccessException`. Services throw them with a user-friendly message, and servlets catch `ForensicsException` in one place and show it as a red flash message.

**Q: How does role-based access work?**
The `Role` enum has methods like `canUploadEvidence()`. JSPs use them to hide buttons (`<c:if test="${me.role.canUploadEvidence()}">`), and services use them to **enforce** the rule. Hiding a button alone isn't security, because someone could send the request by hand.

**Q: How is the timeline built?**
`TimelineService.build()` loads rows from `timeline_events`, converts custody records into timeline events, puts them all in one `ArrayList`, filters with a lambda (`removeIf`), and sorts with `Collections.sort()` using `TimelineEvent.compareTo()` (by time). The JSP groups them by day using `Collectors.groupingBy`.

**Q: How does log analysis work?**
It reads the file line by line with `BufferedReader`, converts each line to upper case, and checks each keyword with `contains()`. It counts hits in a `LinkedHashMap` with `merge(k, 1, Integer::sum)`. A regex `\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}` finds timestamps so lines can go onto the timeline. It runs on the background thread pool.

**Q: When adding log lines to the timeline, can a user fake the text?**
No. The browser sends only **line numbers**. The server re-reads those lines from the stored file itself.

**Q: What is JSTL / EL?**
EL (`${case.title}`) reads Java objects: it calls `getTitle()`. JSTL gives tags like `<c:forEach>` and `<c:if>`, so JSPs need no Java code (scriptlets).

**Q: Why Tomcat 10 and `jakarta.servlet` instead of `javax.servlet`?**
Java EE moved to the Eclipse Foundation and was renamed Jakarta EE. From Servlet 5 / Tomcat 10 on, the package is `jakarta.*`.

**Q: What is `@MultipartConfig`?**
It tells the servlet to accept `multipart/form-data` (file uploads) and sets size limits (25 MB). The service also enforces its own 20 MB rule with a clear message.

**Q: Normalisation?**
Tables are in 3NF: no repeating groups, every non-key column depends on the whole primary key, and names are stored only once (in `users`) and fetched with JOINs.

**Q: What would you add in future?**
Swing desktop client reusing the services; audit log and user management; BCrypt/Argon2 instead of salted SHA-256 for passwords; a connection pool (HikariCP); PDF reports; email alerts on hash mismatch; and the doc's out-of-scope items (disk/memory forensics, AI analysis).

---

## 7. Scope that was reduced (and why)

Ma'am asked for a medium-level project, so these parts of the original design are **not** built:
User-management screen, Audit-log screen, Login-history screen, Database-backup screen, Splash screen and Settings.
Users are fixed demo accounts (3 roles instead of 4; *Viewer* was dropped).

## 8. Commands cheat-sheet

```powershell
.\start-mysql.ps1   # start database
.\build.ps1         # compile + deploy
.\run.ps1           # start Tomcat → http://localhost:8080/forensics/
.\reset-demo.ps1    # clean demo data
.\stop-mysql.ps1    # stop database
```
