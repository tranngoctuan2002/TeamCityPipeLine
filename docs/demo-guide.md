# Demo guide

A talk of about 38 minutes on getting a project onto TeamCity: two ways to set it up, parameters and artifacts, a CI chain and a CD chain, and a third-party service (SonarQube). You only merge and push during the demo; you never type code.

The talk uses **two TeamCity projects**:

| Project | Built how | Used for |
| --- | --- | --- |
| **Demo2** | By hand in the UI, **pre-built** before the talk | *Showing how*: the screens, one live first step. Nothing deploys from it |
| **Demo1** | Imported from `.teamcity/settings.kts` | *Proving it works*: the CI and CD chains, parameters, artifact, deploy, SonarQube |

Part 1 is the run sheet. Part 2 is what you need to know to present it and answer questions. How each step works is in [pipeline.md](pipeline.md).

| # | Section | Project | Time |
| --- | --- | --- | --- |
| 1 | Create a project, first step, **Run** | Demo2 | 5 min |
| 2 | Tour: parameters, version, artifact, deployment, dependencies, triggers | Demo2 | 7 min |
| 3 | Import settings, View as code | Demo1 | 4 min |
| 4 | Proof: parameters, artifact, deploy, CI and CD chains | Demo1 | 12 min |
| 5 | A third-party service: SonarQube | Demo1 | 8 min |
| | Wrap-up | | 2 min |
| | **Total** | | **38 min** |

**Cuts for a 30-minute slot (about 30 min):**

| Cut | Saves | How |
| --- | --- | --- |
| Section 2 (tour) | 4 min | Show only parameters and dependencies; mention the rest while Demo1 runs |
| 4d (rollback) | 2 min | One sentence, or keep it for Q&A |
| 5 (SonarQube parameters) | 2 min | Show only `env.SONAR_TOKEN` and `sonar.enabled` |

Never cut: the live Run in section 1, the import in section 3, the chain run in 4c, the SonarQube run in section 5.

---

## Part 1: run sheet

### Which project is active

Only **one** project may be active when something deploys, because both would write to the same IIS sites (8082, 8083).

- **Demo2 never deploys.** Its **Deploy** build configurations exist to be shown, so **pause every build configuration in Demo2** except the one you Run live in section 1.
- **Demo1 is active** for sections 3-5.
- **Demo2 must not have Versioned Settings enabled.** If it does, it would write into this repo's `.teamcity/` and overwrite `settings.kts`. When creating a project, if TeamCity offers to import settings, decline.
- Tokens are per project. Demo1's `credentialsJSON:...` tokens only work in Demo1. In Demo2, type secrets in **Password** parameters instead.

### Before the talk

The day before:
- [ ] Demo1: push the latest `settings.kts`, wait for the settings to load, check **Versioned Settings** shows no DSL error, and all 7 CI steps are there.
- [ ] Demo1: run **CI build** by hand once with `sonar.enabled=false` (2 SonarQube steps skipped, build green), then once with `sonar.enabled=true`. The begin, build, end chain has not been run against a real server yet, so rehearse it.
- [ ] Demo2: build it up to **Deploy to Staging** (see [build-from-scratch.md](build-from-scratch.md), chặng 1-8). Leave a **fresh** build configuration for the live first step in section 1, or delete the build configuration you rehearsed with just before the talk.
- [ ] Take **screenshots** as backup while it is green: the build chain, the Tests tab with 3 failures, the SonarQube dashboard, the three sites.
- [ ] `docker compose -f sonarqube/docker-compose.yml pull` (about 1 GB).
- [ ] Reset after the dry run (see [After the demo](#after-the-demo)).

30 minutes before:
- [ ] TeamCity agent **Connected**.
- [ ] Start SonarQube early, it needs a few minutes: `docker compose -f sonarqube/docker-compose.yml up -d`. Check http://localhost:9000.
- [ ] **Demo2:** every build configuration is **paused**, Versioned Settings off. **Demo1:** all 4 builds **active**, latest `main` green.
- [ ] Run **CI build** in Demo1 once to warm up the NuGet cache (about 1-2 minutes per build afterwards).
- [ ] All sites show the price **90.00** and the headline "Welcome to the CI/CD demo".
- [ ] `git tag -f demo-start; git push -f origin demo-start`.
- [ ] Open these tabs, zoomed to 125-150%: TeamCity (Demo2 and Demo1 in two tabs), http://localhost:9000, http://localhost:8082, http://localhost:8083, a terminal in the repo on `main` after `git pull`, the editor with `.teamcity/settings.kts` open.

### 1. Create a project, first step, Run (5 min) — Demo2

**Message:** the concepts below exist in every CI tool (Jenkins, GitHub Actions, GitLab CI). Only the screens differ.

1. **Create project** > **Manually**. Decline any offer to import settings.
2. **Version Control Settings:** attach the GitHub repo. Explain the **VCS root**: where the code is, which branch. The **agent** checks it out.
3. **Build Steps** > **PowerShell** > script file `scripts/check-tools.ps1`. Every step only calls a script that lives in Git.
4. **Run.** Open the log: checkout, then the step. This is the one thing the audience sees run in Demo2.

Detailed screens: [build-from-scratch.md](build-from-scratch.md), chặng 1-2.

### 2. Tour of the finished Demo2 (7 min) — Demo2

Open the pre-built **CI build** and **Deploy to Staging**. Click, don't build. Say "I built these the same way as the step you just saw."

| Screen | Say |
| --- | --- |
| **Parameters** | Three kinds: *configuration* (`%name%`), *environment variable* (`env.NAME`), *password* (encrypted, masked in logs). The same Deploy build becomes Production by changing three values. |
| **General Settings** > build number | `1.0.%build.counter%`: every build gets a version. |
| **Build Steps** | Check tools, restore, build, tests, gate: each one a script. |
| **General Settings** > artifact paths | `out/publish/** => DemoApp.Web.%build.number%.zip`: one zip per build. |
| **Deploy to Staging** > type **Deployment** | One run at a time per site. |
| **Dependencies** | *Snapshot*: tied to one CI build, won't start if it failed. *Artifact*: downloads that CI build's zip, cleaned first. |
| **Triggers** | *Finish build* trigger on Staging; none on Production, so a click is the approval. |

Close with: "That is the manual way. Now the same thing, already running, as code."

### 3. Import settings, View as code (4 min) — Demo1

1. Show how Demo1 was made: **Create project** > **From a repository URL**; TeamCity finds `.teamcity/settings.kts` and offers **Import settings**. Use screenshots, don't repeat it live: the tokens only work in Demo1.
2. Open Demo1: the whole pipeline is there at once: **CI build**, **Deploy to Staging**, **Deploy to Production**.
3. Open **View as code** on a Demo1 build configuration and put it next to `settings.kts`:

| Clicking (Demo2) | Code (`settings.kts`) |
| --- | --- |
| Version Control Settings | `vcs { root(DemoRepo) }` |
| A PowerShell build step | `powerShell { scriptMode = file { path = ... } }` |
| Parameters tab | `params { param(...) }` |
| Triggers tab | `triggers { vcs { ... } }` |
| Dependencies tab | `dependencies { dependency(...) }` |

4. From now on, settings change by **commit and push**, with review and history.

**Message:** UI is fastest to learn. Code is better with several people or environments.

### 4. Proof: parameters, artifact, deploy, two chains (12 min) — Demo1

Open the project's **Build Chains** tab and show the chain:

```
 CI chain                                CD chain
 push ─► CI build ───(green)───► Deploy to Staging ──(manual Run)──► Deploy to Production
         check, restore, build,    same zip, config for Staging,      same zip that passed Staging
         test, gate, artifact      smoke test
```

**4a. Push a change (4 min).**

```powershell
git merge origin/demo/1-new-headline -m "New headline"
git push
```

Wait 1-2 minutes (the VCS trigger polls GitHub and has a quiet period). While **CI build** runs, name the steps.
- When green: **Tests** tab 7 passed.

**4b. Artifact and parameters (4 min).**
- **Artifacts** tab: `DemoApp.Web.1.0.N.zip`, the version in the name. A red build would publish nothing.
- **Deploy to Staging** starts by itself. Log: `Deploying version 1.0.N to Staging` and `Smoke test passed: OK 1.0.N`.
- **Parameters proved:** refresh http://localhost:8082: the new headline and footer `Staging · Version 1.0.N`. Open `C:\inetpub\cicd-demo-staging\Web.config`: `Environment=Staging` and the key, written at deploy time. In Git, `src/DemoApp.Web/Web.config` has `ApiKey` **empty**.
- **Deploy to Production** > **Run**. Refresh http://localhost:8083: same version, same zip, `Environment=Production` from three parameters.

**4c. The chain stops a bug (2 min).**

```powershell
git merge origin/demo/2-discount-bug -m "Apply discount change"
git push
```

- **CI build** is red at **5. Unit tests**: 3 failed, e.g. `ApplyDiscount_ReturnsDiscountedPrice(100,10,90)`.
- No artifact. **Deploy to Staging** did not run. http://localhost:8082 still shows **90.00**.

**4d. Roll back in one click (2 min).** "Marketing wants the old headline back."
- **Deploy to Staging** > **Run custom build** > **Dependencies** tab > **CI build** > an older green build > **Run build**.
- Log: `Deploying version 1.0.<old>`; the smoke test checks for exactly that version.
- Roll forward the same way with the newest **green** CI build. A plain **Run** would start a CI build for the bug.

**Message:** CI proves the change is good, CD moves the proven zip. Nothing is rebuilt on the way, so rollback takes seconds.

### 5. A third-party service: SonarQube (8 min) — Demo1

> Rehearse this section. The begin, build, end chain has not been run against a real server yet.

**Message:** TeamCity orchestrates other tools: the agent checks out the code from **GitHub**, analyses it, and sends the result to a separate service, **SonarQube**.

```
 GitHub ──checkout──► TeamCity agent ──scanner uploads results (token)──► SonarQube server :9000
                          │                                                    │
                          └──── waits for the Quality Gate ◄───────────────────┘
                                pass = continue, fail = CI build red, no artifact
```

**5a. The service (1 min).** Show `sonarqube/docker-compose.yml` and http://localhost:9000: a separate server, in Docker, with its own login. Open project `Demo`.

**5b. The connection (2 min).** On Demo1 **CI build** > **Parameters**:
- `sonar.url` = `http://localhost:9000`, `sonar.key` = `Demo`.
- `env.SONAR_TOKEN` is a **password parameter**, the key to the third party. In Git it is only a `credentialsJSON:...` reference; the value is masked in the log. Show where it was created (SonarQube **My Account > Security**).
- `sonar.enabled` = `false`: both SonarQube steps are skipped when it is off.

**5c. Switch it on for one run (4 min).** **Run** > **Run custom build** > **Parameters** > `sonar.enabled` = `true` > **Run build**.
- **3. SonarQube begin** runs **before** the build, because the scanner watches MSBuild compile the C# code. **6. SonarQube end** runs after the tests: it uploads and waits.
- Log of step 6: the Quality Gate result.
- Refresh http://localhost:9000: the analysis for version `1.0.N`.

**5d. The gate decides (1 min).** Explain, don't run:
- `sonar.qualitygate.wait=true`: if SonarQube's gate fails, the step fails, so no artifact and no Staging. Same safety net as a failed test, owned by another system.
- **Two gates:** `7. Quality gate` is our own script (secrets in config). SonarQube's gate checks code quality.
- Cost: with `sonar.enabled=true`, a SonarQube that is down turns CI red at step 3.

**Limits, if asked:** SonarQube Community analyses the main branch only: no branch or pull-request analysis, no comments on GitHub PRs (Developer edition or higher). No coverage report is sent, so a change of 20 or more new lines can fail the 80% coverage condition; the demo commits change one line.

### Wrap-up (2 min)

| | |
| --- | --- |
| Two ways to set up | UI to learn (Demo2), code to scale and review (Demo1) |
| Parameters | One pipeline, different values per environment; secrets masked |
| Artifact | Built once, versioned, deployed everywhere |
| Two chains | CI proves it, CD moves it; a manual step before Production |
| Third party | SonarQube joins through a URL, a token, and a gate that can stop the chain |

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

Then run **CI build** in Demo1 once so Staging, and by hand Production, go back to the starting version. Clear SonarQube with `docker compose -f sonarqube/docker-compose.yml down -v`, then create the project and token again before the next run.

### If something goes wrong live

| What you see | Do this |
| --- | --- |
| A build sits in the queue | **Agents**: is the agent connected? If not, show the backup screenshots and keep talking |
| Demo2's live Run is red | Show the log, say "a real log", and move on to Demo1; section 2 does not depend on it |
| CI is red at **Check tools** or **Restore** | The agent setup changed or the network is down. Use the screenshots |
| CI is red at **3. SonarQube begin** | SonarQube is not up yet (`docker compose ... ps`), or `env.SONAR_TOKEN` is empty or from another project. Set `sonar.enabled` back to `false` and continue |
| CI is red at **6. SonarQube end** | Read the log: gate failed, or begin and build ran from different folders. Show the dashboard and explain it is the gate doing its job |
| Staging didn't start after a green CI | Run **Deploy to Staging** by hand; it reuses the green CI build of the newest commit |
| Two deploys ran at once | Demo2 was not fully paused. Pause it, re-run the Demo1 deploy |
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
