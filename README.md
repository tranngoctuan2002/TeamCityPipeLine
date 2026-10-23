# CI/CD demo kit: today's pipeline vs the improved pipeline

A small ASP.NET (.NET Framework 4.8) app with two TeamCity pipelines, defined as Kotlin DSL in `.teamcity/settings.kts`:

| Pipeline | TeamCity build(s) | What it shows |
| --- | --- | --- |
| **1. Current pipeline (today)** | `Build and copy to server` | Our 7 steps as they are: check tool, detect changes, NuGet, MSBuild, copy config, copy to server, finish. No tests, no versioned artifact, no check after deploy. |
| **2. Improved pipeline** | `CI build` → `Deploy to Staging` (automatic) → `Deploy to Production` (manual) | Version number, unit tests, quality gate, one versioned artifact, config and secrets per environment, smoke test, status, one-click rollback. |

The app shows a headline, a discounted price (100.00 − 10% = **90.00**), the environment and the **version** in the footer. `/Health.ashx` returns `OK <version>` for the smoke test.

> The scripts were run locally (build, tests, gate, deploy to a folder), but not yet on a live TeamCity server. Expect to adjust the DSL `version` for your server. Do a full dry run before the talk.

## Documentation

| Read | When |
| --- | --- |
| [docs/setup-guide.md](docs/setup-guide.md) | Building it: Visual Studio, IIS, free TeamCity, Git, import, secrets, first run, checklist, troubleshooting |
| [docs/demo-guide.md](docs/demo-guide.md) | Presenting it: run sheet for the three live demos, the terms to know, likely questions |
| [docs/pipeline.md](docs/pipeline.md) | Understanding it: what every step does and how, parameters, rollback, next improvements |

## Repository layout

```
DemoApp.sln
src/DemoApp.Core/          price logic + headline (what the demo commits change)
src/DemoApp.Web/           ASP.NET Web Forms site (Default.aspx, Health.ashx)
tests/DemoApp.Tests/       NUnit tests
scripts/                   one PowerShell script per pipeline step (logic in Git, TeamCity steps stay thin)
scripts/current/           steps only the current pipeline uses (copy config, copy to server)
scripts/tests/             self-check for the quality gate
config/current/Web.config  the config file the current pipeline copies (anti-pattern on purpose, fake key)
.teamcity/settings.kts     both pipelines as Kotlin DSL
docs/                      setup, demo and pipeline guides
```

## Branches (the demo commits)

| Branch | Change | Used in |
| --- | --- | --- |
| `main` | Starting point | Setup |
| `demo/1-new-headline` | Headline becomes "Shipped by the pipeline!" | Demo 1 |
| `demo/2-discount-bug` | Bug: discount divides by 10 instead of 100, so the price shows **0.00**; 3 unit tests fail | Demo 2 |

During the demo you only merge and push, never type code (details in the [demo guide](docs/demo-guide.md)):

```
git merge --ff-only origin/demo/1-new-headline && git push     # Demo 1
git merge origin/demo/2-discount-bug -m "Apply discount change" && git push   # Demo 2
git revert --no-edit -m 1 HEAD && git push                     # after the demo: undo the bug
```
