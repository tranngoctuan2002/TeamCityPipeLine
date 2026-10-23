# Pipeline

Two pipelines live side by side in `.teamcity/settings.kts`:

| TeamCity build | Runs | Does |
| --- | --- | --- |
| `1. Current pipeline (today)` > **Build and copy to server** | every push to `main` | Today's 7 steps, unchanged. Kept until we switch. |
| `2. Improved pipeline` > **CI build** | every push to `main` | Builds, versions, tests, gates, and publishes **one** artifact `DemoApp.Web.1.0.<counter>.zip` |
| `2. Improved pipeline` > **Deploy to Staging** | automatically after a green CI build | Deploys that artifact to Staging |
| `2. Improved pipeline` > **Deploy to Production** | **only by hand** | Deploys a CI artifact to Production |

```
push ─► CI build ──(green)──► Deploy to Staging        (automatic)
            │
            └───────────────► Deploy to Production     (Run, by hand)
```

Each TeamCity step only calls a script in `scripts/`, so the logic is versioned with the code and can be run on a laptop.

## CI build (`ImprovedCi`)

| # | Step | Script | Fails the build when |
| --- | --- | --- | --- |
| 1 | Check tools | `check-tools.ps1` | MSBuild, the web targets, the .NET SDK component of Build Tools, or `dotnet` is missing |
| 2 | Restore NuGet | `restore.ps1` | a package cannot be restored |
| 3 | Build + version | `build.ps1 -Version %build.number%` | the build fails. Stamps `1.0.<counter>` into `AssemblyInformationalVersion` and publishes the site to `out/publish` |
| 4 | Unit tests | `test.ps1` | any NUnit test fails. Results (`TestResults/*.trx`) appear on the **Tests** tab |
| 5 | Quality gate | `quality-gate.ps1` | a `*.config` under `src/` holds a value for a key like password/secret/apikey/token, or a connection string holds a password |
| 6 | Publish artifact | artifact rule, no script | (artifact is published only if steps 1-5 all passed) |

Build number format: `1.0.%build.counter%`. The same number is in the zip name, the DLL, the site footer and `/Health.ashx`.

## Deploy builds (`DeployStaging`, `DeployProduction`)

They never compile. A snapshot dependency pins them to a CI build, and an artifact dependency downloads that build's zip into `artifact/` (cleaned first).

| # | Step | Script | What it does |
| --- | --- | --- | --- |
| 7+8 | Config + deploy | `deploy.ps1` | Unzips, writes `Environment` and `ApiKey` into `Web.config`, sets `debug="false"`, puts up `app_offline.htm`, mirrors the files into the site folder with robocopy, removes `app_offline.htm`. Sets the deploy's build number to the version. |
| 9 | Smoke test | `smoke-test.ps1` | Calls `<site url>/Health.ashx` up to 10 times; passes only on HTTP 200 with exactly `OK <deployed version>` |
| 10 | Set build status | `set-status.ps1` | Status text `Deployed 1.0.N to <Environment>` |

On failure:

- **Secret empty:** the deploy stops before touching the site.
- **Copy fails** (e.g. a locked file): `app_offline.htm` **stays up**, so nobody sees a half-copied site. Fix the cause and re-run, or roll back.
- **Smoke test fails:** the build is red. The site runs the new files; roll back if needed.

## Parameters

Project parameters (root project, `params { }` in `settings.kts`):

| Parameter | Default | Set it to |
| --- | --- | --- |
| `demo.repo.url` | `https://github.com/your-org/cicd-demo-kit.git` | your repository URL |
| `site.current.path` / `site.current.url` | `C:\inetpub\cicd-demo-current` / `http://localhost:8081` | the old pipeline's IIS site |
| `site.staging.path` / `site.staging.url` | `C:\inetpub\cicd-demo-staging` / `http://localhost:8082` | the Staging IIS folder and its URL as seen from the agent |
| `site.production.path` / `site.production.url` | `C:\inetpub\cicd-demo-production` / `http://localhost:8083` | the Production IIS folder and URL |

Secrets (password parameters, one per deploy build):

| Build | Parameter | Value to create |
| --- | --- | --- |
| Deploy to Staging | `env.DEMO_API_KEY` | the **Staging** API key, as a TeamCity token |
| Deploy to Production | `env.DEMO_API_KEY` | the **Production** API key, as a TeamCity token |

Create each one like this. The real values never go into Git:

1. In TeamCity: the project > **Edit project** > **Versioned Settings** > **Tokens** > **Generate token**.
2. Paste the real key. TeamCity stores it encrypted and gives back `credentialsJSON:<uuid>`.
3. Put that string into `apiKeyToken = "..."` of `DeployStaging` / `DeployProduction` in `settings.kts`, commit, push.

The token is only a reference; it is safe in Git. TeamCity masks the value in build logs. `deploy.ps1` gets it as an environment variable, not on the command line.

The old pipeline still copies `config/current/Web.config`, which contains a **fake** key on purpose (it shows today's problem). The quality gate scans `src/` only, so it does not fail the CI build on that file. Delete `config/current/` when the old pipeline is retired.

## Import the settings

Import into a **new** project. Do not turn on versioned settings for the existing project that holds today's build: TeamCity would replace that project's settings with this file.

1. Push the repository (all branches) to a Git server TeamCity can reach.
2. **Administration > Projects > Create project > From a repository URL**, enter the URL and credentials.
3. TeamCity finds `.teamcity/settings.kts`. Choose **Import settings from .teamcity/settings.kts**.
4. If TeamCity reports a DSL version mismatch, set `version = "..."` at the top of `settings.kts` to the version it shows, commit, push.
5. Set `demo.repo.url` and the `site.*` parameters in `settings.kts`, generate the two tokens (see above), commit, push. TeamCity reloads the settings from Git on its own.
6. Run **CI build** by hand once. **Deploy to Staging** follows automatically.

Settings changes go through Git from now on: edit `settings.kts`, commit, push.

## Roll back

1. Open **Deploy to Staging** (or **Deploy to Production**), click **...** next to **Run**.
2. **Dependencies** tab > **CI build** > choose the older build (e.g. `1.0.12`).
3. **Run build**.

The same old zip is deployed again, with no rebuild. The smoke test checks that the site now answers `OK 1.0.12`, and the deploy's build number shows `1.0.12`.

The deploy scripts come from the same Git revision as the chosen CI build. Rolling back to a CI build made before these scripts existed runs the older scripts.

## Run the scripts locally

```powershell
.\scripts\check-tools.ps1
.\scripts\restore.ps1
.\scripts\build.ps1 -Configuration Release        # add -Version 1.0.999 to stamp a version
.\scripts\test.ps1
.\scripts\quality-gate.ps1
$env:DEMO_API_KEY = 'any-local-value'
.\scripts\deploy.ps1 -ArtifactDir <folder with one zip> -TargetPath C:\temp\site -Environment Local
```

`build.ps1 -Version` rewrites `src/DemoApp.Web/Properties/AssemblyInfo.cs`. On the agent the clean checkout undoes this. Locally, run `git checkout -- src/DemoApp.Web/Properties/AssemblyInfo.cs` and don't commit the stamped value.

## Checklist: by hand in TeamCity and IIS

Build agent (Windows):

- [ ] Visual Studio Build Tools 2022 with **MSBuild**, **Web development build tools** and the **.NET SDK** component (`check-tools.ps1` fails without it)
- [ ] .NET Framework 4.8 Developer Pack
- [ ] A .NET SDK (`dotnet`) on `PATH`
- [ ] The agent's service account can write to the three site folders

IIS (on the agent machine, or change `site.*` paths to UNC shares and URLs):

- [ ] ASP.NET 4.8 enabled
- [ ] Sites and app pools `cicd-demo-current` (8081), `cicd-demo-staging` (8082) and `cicd-demo-production` (8083). The script is in `README.md`.
- [ ] The agent can reach each site URL (`/Health.ashx`)

TeamCity:

- [ ] New project from the repository URL, settings imported from `.teamcity/settings.kts`
- [ ] DSL `version` matches the server
- [ ] VCS credentials if the repository is private
- [ ] Two tokens generated (Staging key, Production key) and pasted into `settings.kts`
- [ ] Restrict who can run **Deploy to Production** (project roles), or add the Build Approval feature if your TeamCity version has it
- [ ] Optional: the Notifications build feature on the deploy builds (Slack, Teams, email)
- [ ] First run: **CI build** > Staging deploys automatically > check `http://localhost:8082` shows `Version 1.0.N` > run **Deploy to Production** by hand
