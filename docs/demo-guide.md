# Demo guide

A 20-25 minute talk: today's pipeline next to the improved one, with three live demos. You only merge and push during the demo; you never type code.

Part 1 is the run sheet. Part 2 is what you need to know to present it and answer questions. How each step works is in [pipeline.md](pipeline.md).

---

## Part 1: run sheet

### Before the talk

The day before:
- [ ] Setup done and one full dry run of this guide ([setup-guide.md](setup-guide.md)).
- [ ] While the dry run is green, take **screenshots** as a backup: the build chain, the Tests tab with 3 failures, and the three sites.
- [ ] Reset after the dry run (see [After the demo](#after-the-demo)).

30 minutes before:
- [ ] TeamCity agent **Connected**; all four builds green on the latest `main`.
- [ ] Run **CI build** once to warm up the NuGet cache, so live builds take about 1-2 minutes.
- [ ] All three sites show the price **90.00** and the headline "Welcome to the CI/CD demo".
- [ ] Before the talk, tag the starting point so you can reset later: `git tag -f demo-start; git push -f origin demo-start`.
- [ ] Open these tabs, zoomed to 125-150%:
  1. TeamCity: the project overview, both pipelines visible.
  2. http://localhost:8081 (current), http://localhost:8082 (Staging), http://localhost:8083 (Production).
  3. A terminal in the repo folder, on `main`, after `git pull`.
  4. The editor with `.teamcity/settings.kts` and `scripts/` open.

### 0. The problem (2 min)

Show the **1. Current pipeline** build and its 7 steps. Name the four problems:

1. **No tests:** a bug goes straight to the server.
2. **No versioned artifact:** you can't tell which code is running, and there's nothing to roll back to. The footer says `local-dev`.
3. **Config with secrets in Git:** open `config/current/Web.config` and point at `ApiKey`.
4. **No check after deploy:** a green build can mean a broken site.

### 1. Tour of the new pipeline (3 min)

- **2. Improved pipeline**: CI build, then Deploy to Staging (automatic), then Deploy to Production (manual). Open the **build chain** view.
- In the editor, show that the pipeline is **code in Git** (`settings.kts`) and that every step is a **script in Git** (`scripts/`).
- The key idea: **build once, deploy the same zip everywhere.**

### 2. Demo 1: a change flows through (5-6 min)

```powershell
git merge origin/demo/1-new-headline -m "New headline"
git push
```

While it runs:
1. **Both pipelines start** on the same push.
2. Open the **CI build** while it runs and talk through the steps: check tools, restore, build + version, tests, gate.
3. When CI is green:
   - **Tests** tab: 7 passed.
   - **Artifacts** tab: `DemoApp.Web.1.0.N.zip`, the version in the file name.
4. **Deploy to Staging** starts by itself. Open its log:
   - `Deploying version 1.0.N to Staging`
   - smoke test `Smoke test passed: OK 1.0.N`
   - status text `Deployed 1.0.N to Staging`
5. Refresh http://localhost:8082: the new headline "Shipped by the pipeline!", footer `Staging · Version 1.0.N`.
6. Compare http://localhost:8081: it has the new headline too, but the footer still says `local-dev`.
7. Production is **manual**: **Deploy to Production** > **Run**. Refresh http://localhost:8083: same version as Staging, so the same zip.

**Message:** every change gets a version, is tested, is deployed the same way everywhere, and is checked after the deploy.

### 3. Demo 2: a bug is stopped (5 min)

The change looks like a harmless refactor of the discount code, but it divides by 10 instead of 100.

```powershell
git merge origin/demo/2-discount-bug -m "Apply discount change"
git push
```

1. **Current pipeline:** green. Refresh http://localhost:8081: the price is **0.00**. The bug reached the server and nobody was told.
2. **Improved pipeline:**
   - The **CI build** is red at **4. Unit tests**. The **Tests** tab shows 3 failed, e.g. `ApplyDiscount_ReturnsDiscountedPrice(100,10,90)`: expected 90, was 0.
   - **No artifact** was published.
   - **Deploy to Staging** did not run.
   - Refresh http://localhost:8082: still **90.00**.

**Message:** the pipeline is a safety net. A failed test means nothing gets deployed.

Even if a bug slipped past the tests, the smoke test would catch it: `Health.ashx` runs the price logic and answers HTTP 500 `FAIL`.

### 4. Demo 3: roll back in one click (3 min)

The story: "Marketing wants the old headline back right now."

1. **Deploy to Staging** > the **...** next to **Run** > **Dependencies** tab > **CI build** > pick the build from before Demo 1 > **Run build**.
2. Log: `Deploying version 1.0.<old>`, then the smoke test checks for exactly that version.
3. Refresh http://localhost:8082: the old headline, the old version.
4. Roll forward again: use the same dialog and pick the **Demo 1** CI build, the newest green one. Don't use a plain **Run** here: the newest commit is the Demo 2 bug, so TeamCity would start a CI build for it, which fails.

**Message:** nothing was rebuilt. The exact zip that was tested before is deployed again, in seconds.

### 5. Secrets (2 min)

1. `src/DemoApp.Web/Web.config` in Git: `ApiKey` is **empty**.
2. `settings.kts`: only `credentialsJSON:...` tokens. The real values live encrypted on the TeamCity server.
3. Open `C:\inetpub\cicd-demo-staging\Web.config` on the server: `Environment=Staging` and the key, written at deploy time.
4. The deploy build log never shows the value; TeamCity masks it.
5. The **quality gate** fails the CI build if someone commits a key under `src/`. You can show the self-check: `.\scripts\tests\quality-gate.tests.ps1`.

### 6. Wrap-up (2 min)

| | Before | After |
| --- | --- | --- |
| Tests | none | run on every push; a red test stops everything |
| What's running? | `local-dev` | `1.0.N` in the zip, the DLL, the page and the health check |
| Rollback | rebuild from an old commit and hope | re-deploy an older zip in one click |
| Config and secrets | a file per server in Git | one artifact; values and secrets per environment from TeamCity |
| After deploy | nothing | smoke test against the exact version |
| Production | the same build copies to the server | manual, same zip that passed Staging |

Next steps: see [Next improvements](pipeline.md#next-improvements).

### After the demo

Undo the bug (keeps history, safe):

```powershell
git revert --no-edit -m 1 HEAD
git push
```

To **rehearse again** from the start, move `main` back to the tag. This rewrites `main` on the demo repo, so only do it there:

```powershell
git reset --hard demo-start
git push --force-with-lease origin main
```

Then run **CI build** once so Staging, and by hand Production, go back to the starting version.

### If something goes wrong live

| What you see | Do this |
| --- | --- |
| A build sits in the queue | **Agents**: is the agent connected? If not, show the backup screenshots and keep talking |
| CI is red at **Check tools** or **Restore** | The agent setup changed or the network is down. Use the screenshots |
| Staging didn't start after a green CI | Run **Deploy to Staging** by hand; it reuses the green CI build of the newest commit |
| Smoke test fails with "Unable to connect" | The IIS site or app pool is stopped: start it in IIS Manager and re-run the deploy |
| The site says "Deploying a new version" | A copy failed and the site was left offline on purpose. Re-run the deploy, then explain this is the safe behavior |

---

## Part 2: what to know before presenting

### The five messages
1. **Build once, deploy many:** one zip per commit, and the same zip goes to Staging and then Production.
2. **Every build has a version** (`1.0.<counter>`) that you can see in the artifact name, the DLL, the page footer and `/Health.ashx`.
3. **Nothing reaches a server unless the tests and the quality gate pass.**
4. **Config and secrets stay out of the artifact and out of Git;** each environment's values are added at deploy time.
5. **Every deploy is checked (smoke test) and can be undone (rollback).**

### CI/CD terms
| Term | Meaning here |
| --- | --- |
| **CI** (continuous integration) | Every push is built and tested automatically: the **CI build** |
| **CD** (continuous delivery) | Every green build *can* go to production with one click; Production is a manual **Run** |
| Continuous *deployment* | Production goes out automatically too. We don't do that, on purpose |
| **Artifact** | The output of a build that gets stored, here `DemoApp.Web.1.0.N.zip` |
| **Quality gate** | A check that fails the build, not just a report |
| **Smoke test** | A quick "is it up and is it the right version" check right after the deploy |
| **Rollback** | Deploying an older, already tested artifact again |
| **Promotion** | Moving the same artifact from Staging to Production |

### TeamCity terms
| Term | Where you see it |
| --- | --- |
| **Project** | `1. Current pipeline` and `2. Improved pipeline` are subprojects |
| **Build configuration** | One "build" in a project, e.g. CI build or Deploy to Staging (4 in total) |
| **Build step** | One line in a build, here always a PowerShell script |
| **Agent** | The machine that runs the steps (this PC) |
| **VCS trigger** | Starts the CI build on every push to `main` |
| **Finish build trigger** | Starts Deploy to Staging when a CI build finishes green |
| **Snapshot dependency** | Ties a deploy to one CI build at the same commit, and won't start if CI failed |
| **Artifact dependency** | Downloads the zip of that CI build into the deploy |
| **Build chain** | CI, then the deploys, shown as one chain |
| **Build number** | `1.0.%build.counter%`, the counter rising by 1 with each build |
| **Parameter** / **password parameter** | Settings like site paths; password values are stored encrypted and masked in logs |
| **Token** (`credentialsJSON:`) | A reference to a secret stored on the server, safe to keep in Git |
| **Versioned settings / Kotlin DSL** | The whole pipeline defined in `.teamcity/settings.kts` in Git |
| **Service message** | A line like `##teamcity[buildNumber '1.0.5']` that a script prints to talk to TeamCity |
| **Deployment build type** | Marks Deploy to Staging/Production as deployments. Each is also limited to one running build at a time |
| **XML report processing** | A build feature that reads the test results file and fills the Tests tab |

### .NET and IIS terms
| Term | Meaning here |
| --- | --- |
| **MSBuild** | The .NET Framework build engine (part of Visual Studio Build Tools) |
| **Web publish** | MSBuild copies only what the site needs (pages, `bin`, `Web.config`) to `out/publish` |
| **AssemblyInformationalVersion** | A version text inside the DLL; the build writes `1.0.N` into it and the page reads it |
| **NUnit** | The test framework; `dotnet test` runs the tests |
| **Web.config `appSettings`** | Key/value settings the app reads; the deploy writes `Environment` and `ApiKey` |
| **app_offline.htm** | If this file is in the site folder, ASP.NET stops the app and shows the file, so nobody hits a half-copied site |
| **robocopy /MIR** | Makes the site folder an exact copy of the new version, deleting files that were removed |
| **Health endpoint** | `/Health.ashx` runs the core logic and answers `OK <version>` (HTTP 200) or `FAIL` (HTTP 500) |

### Your real pipeline vs this one

To confirm against the real build configuration (**View as code**). The first three lines of today's build log are TeamCity's own work, not steps:

| Today's build log | In the new pipeline |
| --- | --- |
| Updating tools for build, Publishing internal artifacts, Updating sources | Same, done by TeamCity |
| NuGet Installer | `restore.ps1` |
| Detect changed site | Not needed: the VCS trigger finds the changes. With several sites, use one CI build per site with trigger rules |
| Build notification | `set-status.ps1` plus the Notifications build feature (sent once the result is known) |
| .NET Build | `build.ps1` (now also stamps the version and publishes) |
| Mark build success | Removed: TeamCity decides success from the steps, so it is never forced green |
| Run automation | After the Staging deploy, as a gate before Production |
| Finish | Removed |

### Questions you may get

**Why not build again for Production?**
A new build is new, untested code: compiler, packages and timing can differ. Deploying the same zip means Production runs exactly what was tested on Staging.

**Why not Web.config transforms (`Web.Release.config`)?**
Transforms bake the environment's values in at build time, so you'd need one build per environment, and the secrets would sit in Git. Writing the values at deploy time keeps one artifact and keeps secrets in TeamCity.

**Why PowerShell scripts instead of TeamCity's built-in runners?**
The logic is versioned with the code, reviewed in pull requests, runs on a laptop, and can move to another CI tool (Jenkins, GitHub Actions) unchanged. TeamCity only orchestrates.

**Is there downtime?**
A few seconds while `app_offline.htm` is up and the files are copied. Zero downtime needs two sites behind a switch (blue-green), which is a later step.

**What if the smoke test fails?**
The deploy build turns red and the team sees it. Roll back with one click. Rolling back automatically is a possible next step.

**Where are the secrets?**
Encrypted on the TeamCity server. Git only holds token references, the build log masks the value, and the script gets it as an environment variable, not on the command line.

**What about the database?**
This demo app has none. A real app needs a migration step in the deploy, plus a backup before it, because a database rollback is harder than a code rollback.

**What does TeamCity cost?**
TeamCity On-Premises Professional is free: 3 agents, up to 100 build configurations. This setup uses 4.

**How long does a run take?**
About 1-2 minutes for CI with a warm cache, and seconds for a deploy.

**Can it build pull requests?**
Yes: add the Pull Requests and Commit Status Publisher build features and widen the trigger. See [Next improvements](pipeline.md#next-improvements).
