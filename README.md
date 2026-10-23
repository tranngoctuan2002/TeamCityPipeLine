# CI/CD demo kit: today's pipeline vs the improved pipeline

A small ASP.NET (.NET Framework 4.8) app with two TeamCity pipelines, defined as Kotlin DSL in `.teamcity/settings.kts`:

| Pipeline | TeamCity build(s) | What it shows |
| --- | --- | --- |
| **1. Current pipeline (today)** | `Build and copy to server` | Our 7 steps as they are: check tool, detect changes, NuGet, MSBuild, copy config, copy to server, finish. No tests, no versioned artifact, no check after deploy. |
| **2. Improved pipeline** | `CI build` → `Deploy to Staging` (automatic) → `Deploy to Production` (manual) | Version number, unit tests, quality gate, one versioned artifact, config per environment, smoke test, notify, one-click rollback. |

The app shows a headline, a discounted price (100.00 − 10% = **90.00**), the environment and the **version** in the footer. `/Health.ashx` returns `OK <version>` for the smoke test.

> Not tested on a live TeamCity server. Expect to adjust the DSL `version` and agent paths for your setup. Do a full dry run before the talk.

## Repository layout

```
DemoApp.sln
src/DemoApp.Core/          price logic + headline (what the demo commits change)
src/DemoApp.Web/           ASP.NET Web Forms site (Default.aspx, Health.ashx)
tests/DemoApp.Tests/       NUnit tests
scripts/                   one PowerShell script per pipeline step (logic in Git, TeamCity steps stay thin)
scripts/current/           steps only the current pipeline uses (copy config, copy to server)
config/current/Web.config  the config file the current pipeline copies (anti-pattern on purpose, fake key)
.teamcity/settings.kts     both pipelines as Kotlin DSL
```

## Branches (the demo commits)

| Branch | Change | Used in |
| --- | --- | --- |
| `main` | Starting point | Setup |
| `demo/1-new-headline` | Headline becomes "Shipped by the pipeline!" | Demo 1 |
| `demo/2-discount-bug` | Bug: discount divides by 10 instead of 100, so the price shows **0.00**; a unit test fails | Demo 2 |

During the demo you only merge and push, never type code:

```
git merge --ff-only origin/demo/1-new-headline && git push     # Demo 1
git merge origin/demo/2-discount-bug -m "Apply discount change" && git push   # Demo 2
git revert --no-edit -m 1 HEAD && git push                     # after the demo: undo the bug
```

## Setup (about 1 hour, do it a day before)

### 1. Build agent (Windows)

- Visual Studio Build Tools 2022 with **MSBuild**, **Web development build tools** and the **.NET SDK** component
- .NET Framework 4.8 Developer Pack
- .NET SDK 8 (runs the NUnit tests with `dotnet test`)
- IIS with ASP.NET 4.8 enabled; the agent's service account needs write access to `C:\inetpub\cicd-demo-*`

### 2. IIS sites (on the agent machine, or change the paths/URLs in the DSL)

| Site | Folder | URL | Deployed by |
| --- | --- | --- | --- |
| cicd-demo-current | `C:\inetpub\cicd-demo-current` | http://localhost:8081 | Current pipeline |
| cicd-demo-staging | `C:\inetpub\cicd-demo-staging` | http://localhost:8082 | Deploy to Staging |
| cicd-demo-production | `C:\inetpub\cicd-demo-production` | http://localhost:8083 | Deploy to Production |

```powershell
Import-Module WebAdministration
foreach ($s in @(@('current',8081), @('staging',8082), @('production',8083))) {
    $path = "C:\inetpub\cicd-demo-$($s[0])"
    New-Item $path -ItemType Directory -Force | Out-Null
    New-WebAppPool "cicd-demo-$($s[0])"
    New-Website -Name "cicd-demo-$($s[0])" -Port $s[1] -PhysicalPath $path -ApplicationPool "cicd-demo-$($s[0])"
}
```

### 3. Git repository

Push this folder (with all three branches) to a repo TeamCity can read:

```
git remote add origin <your repo url>
git push -u origin main demo/1-new-headline demo/2-discount-bug
```

### 4. TeamCity

1. **Administration > Projects > Create project > From a repository URL**, enter the repo URL.
2. TeamCity detects `.teamcity/settings.kts`; choose **Import settings from .teamcity/settings.kts**.
3. If TeamCity reports a DSL version mismatch, set `version = "..."` at the top of `settings.kts` to the version it shows, commit, push.
4. Set `demo.repo.url` to your repo URL (in `settings.kts`), and VCS credentials in the VCS root if the repo is private.
5. Secrets, one per environment: **Project Settings > Versioned Settings > Tokens > Generate token** for the Staging key and again for the Production key, then paste each `credentialsJSON:...` token as `apiKeyToken` of `DeployStaging` / `DeployProduction` in `settings.kts`. A deploy with an empty key fails on purpose. Details: [docs/pipeline.md](docs/pipeline.md).
6. Run each build once by hand: `Build and copy to server`, `CI build` (Deploy to Staging follows automatically), `Deploy to Production`.
7. Check all three sites show **90.00**, and Staging/Production show a version like `1.0.1`.

## Rollback

`Deploy to Staging` > **Run...** (the `...` button) > **Dependencies** tab > pick an older `CI build` > **Run build**. The same old artifact is deployed again; no rebuild.

## Optional extras

- **Pull requests:** widen the CI trigger to `+:*` and add the Pull Requests + Commit Status Publisher build features.
- **Notifications:** add the Notifications build feature (Slack, Teams, email) to the deploy builds.
- **Approval for Production:** recent TeamCity versions have a Build Approval feature; otherwise keep Production as a manual run with restricted permissions.
- **More quality gates:** dotCover coverage threshold, SonarQube, OWASP Dependency-Check (see `scripts/quality-gate.ps1`).
