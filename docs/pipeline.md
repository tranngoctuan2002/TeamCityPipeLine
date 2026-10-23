# Pipeline reference: what each step does and how

Two pipelines live side by side in `.teamcity/settings.kts`:

| TeamCity build | Starts | Does |
| --- | --- | --- |
| `1. Current pipeline (today)` > **Build and copy to server** | every push to `main` | Today's 7 steps, unchanged. Kept until we switch. |
| `2. Improved pipeline` > **CI build** | every push to `main` | Builds, versions, tests, gates, and publishes **one** artifact `DemoApp.Web.1.0.<counter>.zip` |
| `2. Improved pipeline` > **Deploy to Staging** | automatically after a green CI build | Deploys that artifact to Staging and checks it |
| `2. Improved pipeline` > **Deploy to Production** | **only by hand** | Deploys a CI artifact to Production and checks it |

```
push ─► CI build ──(green)──► Deploy to Staging        (automatic)
            │
            └───────────────► Deploy to Production     (Run, by hand)
```

Every TeamCity step only calls a script in `scripts/`. The logic is versioned with the code, can run on a laptop, and would carry over to another CI tool unchanged.

Setting it up: [setup-guide.md](setup-guide.md). Presenting it: [demo-guide.md](demo-guide.md).

---

## CI build (`ImprovedCi`)

**Before step 1, TeamCity itself:** the **VCS trigger** sees a push to `main` and queues the build. The build number is set to `1.0.%build.counter%`, e.g. `1.0.7`. The agent then does a **clean checkout** of that commit, so nothing is left over from earlier builds.

Steps run in order, and each runs only if every earlier step passed.

### 1. Check tools: `check-tools.ps1`
- **What:** fails within seconds if the agent can't build this app, instead of failing halfway through with a cryptic error.
- **How:**
  - Finds `MSBuild.exe` with `vswhere.exe` (Visual Studio's own locator).
  - Checks for `Microsoft.WebApplication.targets` (web build tools), the .NET SDK resolver inside MSBuild (needed for the SDK-style projects), and `dotnet`.
  - Prints `##teamcity[setParameter name='env.MSBUILD_PATH' ...]`, so the later steps reuse that MSBuild path.

### 2. Restore NuGet: `restore.ps1`
- **What:** downloads the NuGet packages: NUnit, the test SDK, and the .NET 4.8 reference assemblies.
- **How:** `MSBuild DemoApp.sln /t:Restore` fills the agent's NuGet cache.
- **Note for real apps:** projects that use `packages.config` (common in older .NET Framework apps) also need `/p:RestorePackagesConfig=true`.

### 3. Build + version: `build.ps1 -Version %build.number%`
- **What:** compiles in Release, stamps the version, and publishes the site.
- **How:**
  1. Replaces `AssemblyInformationalVersion("local-dev")` in `src/DemoApp.Web/Properties/AssemblyInfo.cs` with `1.0.N`.
  2. `MSBuild DemoApp.sln /p:Configuration=Release` builds the whole solution, tests included.
  3. A second MSBuild call with `DeployOnBuild=true`, `WebPublishMethod=FileSystem` and `PublishUrl=out/publish` copies only what the site needs (`Default.aspx`, `Health.ashx`, `Web.config`, `bin/`) to `out/publish`.
  4. At run time, `AppVersion.cs` reads the stamped version, so the page footer and `/Health.ashx` show `1.0.N`.

### 4. Unit tests: `test.ps1`
- **What:** runs the NUnit tests for the business logic (`PriceCalculator`).
- **How:**
  - `dotnet test --no-build -c Release` tests exactly the binaries from step 3.
  - `--logger trx` writes `TestResults/*.trx`. The **XML report processing** build feature reads that file and fills the **Tests** tab.
  - A failed test means a non-zero exit code, so the step fails, the rest is skipped, and there's no artifact.

### 5. Quality gate: `quality-gate.ps1`
- **What:** fails the build if a config file under `src/` contains a hard-coded secret.
- **How:**
  - Loads every `src/**/*.config` as XML.
  - Fails on any `appSettings` key that looks like a secret (password, pwd, secret, api key, token, credential) and has a value.
  - Fails on any connection string with a literal `Password=` or `Pwd=`.
  - Placeholders like `%DB_PASSWORD%` are allowed.
  - Self-check: `scripts/tests/quality-gate.tests.ps1`.
- **Not scanned:** `config/current/` holds the old pipeline's fake key on purpose. Delete that folder when the old pipeline goes.

### 6. Publish artifact (no script)
- **What:** stores **one** versioned zip, only for green builds.
- **How:**
  - The artifact rule `out/publish/** => DemoApp.Web.%build.number%.zip` zips the publish folder.
  - `publishArtifacts = SUCCESSFUL` means it's only stored when every step passed. The zip appears on the build's **Artifacts** tab.

---

## Deploy builds (`DeployStaging`, `DeployProduction`)

Both come from the same template (`DeployBuild` in `settings.kts`), so they are identical except for the environment name, the site path and URL, the secret, and the trigger. **They never compile anything.**

**Before step 7, TeamCity itself:**
- **Trigger:** Staging has a **finish build trigger**, so it starts when a CI build on `main` finishes green. Production has none: someone clicks **Run**.
- **Snapshot dependency on CI:** ties the deploy to one CI build at the same commit. If that CI build failed, the deploy doesn't start. On a manual run you can pick any older CI build on the **Dependencies** tab; that's the rollback.
- **Artifact dependency:** downloads that CI build's `DemoApp.Web.*.zip` into `artifact/`, emptied first, so only that one zip is there.
- **Secret:** the password parameter `env.DEMO_API_KEY` becomes an environment variable, and TeamCity masks its value in the log.
- **Deployment build type with one build at a time:** two deploys never write to the same site at once.

### 7 + 8. Config per environment, deploy: `deploy.ps1`
- **What:** turns the generic artifact into this environment's site and swaps it in safely.
- **How:**
  1. Stops if `DEMO_API_KEY` is empty, or if `artifact/` doesn't hold exactly one zip. The site isn't touched.
  2. Reads the version from the file name (`DemoApp.Web.1.0.7.zip` gives `1.0.7`). Prints:
     - `##teamcity[buildNumber '1.0.7']`, so the deploy shows the version it deployed;
     - `##teamcity[setParameter name='env.DEPLOYED_VERSION' ...]`, for the next steps.
  3. Unzips to a temp folder and edits `Web.config` as XML: `Environment` is the environment name, `ApiKey` is the secret, and `compilation debug` is `false`.
  4. Writes `app_offline.htm` into the site folder. ASP.NET then stops the app and shows that page to visitors.
  5. `robocopy /MIR` mirrors the new files into the site folder:
     - it copies new and changed files and deletes removed ones;
     - `app_offline.htm` is kept;
     - `/R:3 /W:5` means 3 retries 5 seconds apart, instead of robocopy's default of weeks.
  6. **Copy OK:** deletes `app_offline.htm`, and the app restarts on the new code. **Copy failed:** `app_offline.htm` **stays**, so nobody sees a half-copied site, and the build fails.

### 9. Smoke test: `smoke-test.ps1 -Url <site>`
- **What:** proves the site is up **and** running the version just deployed.
- **How:**
  - Calls `<site>/Health.ashx` up to 10 times, 3 seconds apart.
  - `Health.ashx` runs the real price logic. It answers HTTP 200 `OK <version>` if 100 − 10% = 90, otherwise HTTP 500 `FAIL <version>`.
  - The test passes only on HTTP 200 with **exactly** `OK <DEPLOYED_VERSION>`.
  - So an old version still running, a failed restart, or broken logic all turn the build red.

### 10. Set build status: `set-status.ps1`
- **What:** the build's status text becomes `Deployed 1.0.7 to Staging`, visible in the build list and in notifications.
- **How:** prints `##teamcity[buildStatus text='...']`.

---

## Current pipeline (`CurrentBuildAndCopy`), for comparison

| # | Step | Script | Problem it shows |
| --- | --- | --- | --- |
| 1 | Check the tool | `check-tools.ps1` | |
| 2 | Detect code changes | `detect-changes.ps1` | Only lists changed files; the VCS trigger already knows them |
| 3 | Install NuGet | `restore.ps1` | |
| 4 | Build with MSBuild | `build.ps1` (no `-Version`) | No version: the site shows `local-dev` |
| 5 | Copy config | `scripts/current/copy-config.ps1` | A config file per server in Git, with a key in it |
| 6 | Copy artifact to hosting server | `scripts/current/copy-to-server.ps1` | No tests before it, no stored artifact, no rollback, no `app_offline.htm` |
| 7 | Finish | inline | Nothing checks the site |

---

## Parameters and secrets

Project parameters (`params { }` at the top of `settings.kts`):

| Parameter | Default | Set it to |
| --- | --- | --- |
| `demo.repo.url` | `https://github.com/your-org/cicd-demo-kit.git` | your repository URL |
| `site.current.path` / `site.current.url` | `C:\inetpub\cicd-demo-current` / `http://localhost:8081` | the old pipeline's IIS site |
| `site.staging.path` / `site.staging.url` | `C:\inetpub\cicd-demo-staging` / `http://localhost:8082` | the Staging folder (local or `\\server\share`) and its URL as seen from the agent |
| `site.production.path` / `site.production.url` | `C:\inetpub\cicd-demo-production` / `http://localhost:8083` | the Production folder and URL |

Secrets (one password parameter per deploy build):

| Build | Parameter | Value to create |
| --- | --- | --- |
| Deploy to Staging | `env.DEMO_API_KEY` | the **Staging** API key, as a TeamCity token |
| Deploy to Production | `env.DEMO_API_KEY` | the **Production** API key, as a TeamCity token |

Generate each token in **Versioned Settings > Tokens** and paste the `credentialsJSON:...` string as `apiKeyToken` in `settings.kts`. The steps are in [setup-guide.md](setup-guide.md#6-secrets-one-per-environment). The real values never go into Git.

## Roll back

1. **Deploy to Staging** (or **Production**) > **...** next to **Run**.
2. **Dependencies** tab > **CI build** > choose the older build, e.g. `1.0.12`.
3. **Run build**.

The same old zip is deployed again, with no rebuild. The smoke test checks that the site now answers `OK 1.0.12`.

The deploy scripts come from the same Git revision as the chosen CI build. Rolling back to a CI build made before these scripts existed runs the older scripts.

## Run the scripts locally

```powershell
.\scripts\check-tools.ps1
.\scripts\restore.ps1
.\scripts\build.ps1 -Configuration Release        # add -Version 1.0.999 to stamp a version
.\scripts\test.ps1
.\scripts\quality-gate.ps1
.\scripts\tests\quality-gate.tests.ps1           # proves the gate passes clean configs and fails on secrets
$env:DEMO_API_KEY = 'any-local-value'
.\scripts\deploy.ps1 -ArtifactDir <folder with one zip> -TargetPath C:\temp\site -Environment Local
```

`build.ps1 -Version` rewrites `src/DemoApp.Web/Properties/AssemblyInfo.cs`. On the agent, the clean checkout undoes this. Locally, run `git checkout -- src/DemoApp.Web/Properties/AssemblyInfo.cs` and don't commit the stamped value.

## Next improvements

In order of value for effort:

1. **Production takes only what passed Staging:** make Deploy to Production depend on Deploy to Staging instead of on CI directly.
2. **Automation tests on Staging:** run UI/API tests after the Staging deploy, as the gate before Production.
3. **Pull request builds:** widen the CI trigger to `+:*`, add the Pull Requests and Commit Status Publisher build features, and require a green CI before merging.
4. **Keep rollback artifacts:** add a clean-up rule that keeps the artifacts of the last 20 successful CI builds.
5. **Fail if no tests ran:** add a failure condition, so tests that silently stop running are caught.
6. **Notifications:** add the Notifications build feature to the deploy builds (failure and fixed only).
7. **Production approval:** restrict who may run Deploy to Production, or use the Build Approval feature if your TeamCity version has it.
8. **More gates:** a vulnerable package scan (`dotnet list package --vulnerable`, or OWASP Dependency-Check for `packages.config`), and a dotCover coverage threshold.
9. **Several sites in one repo:** one CI build and deploy per site, generated in `settings.kts` with trigger rules like `+:src/SiteA/**`.
10. **Zero downtime:** two IIS sites behind a switch (blue-green) instead of `app_offline.htm`.
