# Setup guide: from zero to a green pipeline

Do this a day before the demo. It takes about 1-2 hours the first time. Everything runs on **one Windows PC**: the TeamCity server, the build agent, and IIS with the three sites.

```
 Git repo (GitHub/GitLab)
        │ push
        ▼
 TeamCity server (http://localhost:8111) ──► Build agent (same PC) ──► IIS sites on the same PC
                                                                        :8081 current pipeline
                                                                        :8082 Staging
                                                                        :8083 Production
```

Run every PowerShell command below in **PowerShell as Administrator**.

## 1. Build tools (Visual Studio)

The agent needs MSBuild with web targets and the .NET SDK component.

1. Open **Visual Studio Installer** > your Visual Studio 2022 (or Build Tools 2022) > **Modify**.
2. Workloads: **ASP.NET and web development** (Build Tools: **Web development build tools**).
3. **Individual components**: tick **.NET SDK** and **.NET Framework 4.8 targeting pack**.
4. **Modify**.

Same thing from the command line (Community edition path; change it for Build Tools):

```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify `
  --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community" `
  --add Microsoft.NetCore.Component.SDK --add Microsoft.Net.Component.4.8.TargetingPack --passive
```

Check: in the repo folder, `.\scripts\check-tools.ps1` ends with `dotnet : ...` and no error. Git for Windows must also be installed (`git --version`).

## 2. IIS and the three sites

```powershell
# IIS + ASP.NET 4.8 (reboot if Windows asks)
Enable-WindowsOptionalFeature -Online -All -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-ManagementConsole, IIS-ASPNET45, IIS-NetFxExtensibility45, IIS-ISAPIExtensions, IIS-ISAPIFilter

# One site + app pool per pipeline/environment
Import-Module WebAdministration
foreach ($s in @(@('current',8081), @('staging',8082), @('production',8083))) {
    $path = "C:\inetpub\cicd-demo-$($s[0])"
    New-Item $path -ItemType Directory -Force | Out-Null
    New-WebAppPool "cicd-demo-$($s[0])"
    New-Website -Name "cicd-demo-$($s[0])" -Port $s[1] -PhysicalPath $path -ApplicationPool "cicd-demo-$($s[0])"
}
```

Check: **IIS Manager** lists `cicd-demo-current`, `cicd-demo-staging` and `cicd-demo-production`, all started. The pages are empty until the first deploy.

## 3. TeamCity server and agent (free)

**TeamCity On-Premises Professional** is free (3 agents, up to 100 build configurations; this project uses 4). The 14-day trial and the business-email form are for TeamCity Cloud or demo requests; you do not need them.

1. Download the **Windows installer** (`.exe`) of the newest version not marked "do not install" from the docs page
   [Previous releases downloads](https://www.jetbrains.com/help/teamcity/previous-releases-downloads.html). No form, no account.
2. Run the installer:
   - Components: **Build Agent** and **Server**, both as **Windows services**.
   - Server port: keep **8111**.
   - Service accounts: keep **SYSTEM** for both. SYSTEM can already write to `C:\inetpub`. (Demo only; use a dedicated low-privilege account for anything real.)
3. Open `http://localhost:8111`:
   - Data directory: keep the default > **Proceed**.
   - Database: **Internal (HSQLDB)**. Fine for a demo.
   - Accept the license, create the **admin** account.
4. **Agents** > **Unauthorized** > **Authorize** the agent on this PC. It must show as **Connected** and **Authorized**.
5. Note the server version (bottom of every page, e.g. `2026.2`).

## 4. Git repository

1. Create an **empty** repository (no README) on GitHub, GitLab or similar. Private is fine. It must be a repo **you** can push to; if you cloned someone else's, `origin` points at theirs and the push in step 4 will fail.
2. For a private repo, create a personal access token that can read the repo. TeamCity uses it as the password.
3. In `.teamcity/settings.kts` change:
   - `version = "2024.03"` to your TeamCity version from step 3 (e.g. `"2026.2"`);
   - `param("demo.repo.url", "...")` to the repo's HTTPS URL.
4. Create local copies of the demo branches (a fresh clone only has them as `origin/...`), then commit and push all branches:

```powershell
cd <path to this repo>
git fetch --all
git branch demo/1-new-headline origin/demo/1-new-headline
git branch demo/2-discount-bug origin/demo/2-discount-bug
git add .teamcity/settings.kts
git commit -m "Point TeamCity settings at our repo and server version"
git remote set-url origin <your repo url>   # or: git remote add mine <your repo url>
git push -u origin main demo/1-new-headline demo/2-discount-bug
```

If you pushed to a remote named `mine`, use `mine` instead of `origin` in the last command.

## 5. Import the pipelines into TeamCity

Always import into a **new** project. Never enable versioned settings on the project that holds a real production build; TeamCity would replace its settings with this file.

1. **Administration** > **Projects** > **Create project** > **From a repository URL**.
2. Repository URL; for a private repo, username + the access token as password > **Proceed**.
3. TeamCity finds `.teamcity/settings.kts` > choose **Import settings from .teamcity/settings.kts** > **Proceed**.
4. You should see:
   - **1. Current pipeline (today)** > Build and copy to server
   - **2. Improved pipeline** > CI build, Deploy to Staging, Deploy to Production

If TeamCity shows a DSL version or compile error, see Troubleshooting below.

If TeamCity says `did not produce .teamcity/generated_settings.zip artifact`, open the failed "DSL settings generator job" build log. `POM file ...\.teamcity\pom.xml ... does not exist` means `.teamcity/pom.xml` is missing from the repo; it must be committed next to `settings.kts`.

The first DSL run downloads Maven libraries and can take 5-10 minutes. Do not click **Load project settings from VCS** repeatedly; each click queues another build. If the log (Administration > Diagnostics, or `teamcity-versioned-settings.log`) says `Cannot find the last committed revision of project ... disable / enable versioned settings`, open **Edit project > Versioned Settings**, set **Synchronization disabled** > Apply, then enable it again (Kotlin) and choose **Use settings from VCS**, never "Commit current project settings".

From now on settings change through Git: edit `settings.kts`, commit, push. TeamCity reloads within a minute or two.

## 6. Secrets (one per environment)

1. Open the new project > **Edit project** > **Versioned Settings** > **Tokens** (link at the top right) > **Generate token**.
2. Value: the Staging API key (this demo app does not call a real API, so any text works, e.g. `staging-demo-key`). Copy the result `credentialsJSON:...`.
3. Generate a second token for the Production key.
4. In `settings.kts`, paste them as `apiKeyToken = "credentialsJSON:..."` in `DeployStaging` and `DeployProduction`. Commit, push.

Tokens are references to values stored encrypted on the TeamCity server, so they are safe in Git. Without them, CI works but every deploy stops with "ApiKey for Staging is empty", on purpose.

## 7. First run and check

1. **1. Current pipeline** > **Build and copy to server** > **Run**. Then open http://localhost:8081: price **90.00**, footer `Current pipeline · Version local-dev`.
2. **2. Improved pipeline** > **CI build** > **Run**. When green:
   - the **Tests** tab shows 7 passed;
   - the **Artifacts** tab shows `DemoApp.Web.1.0.1.zip`.
3. **Deploy to Staging** starts by itself. Then open http://localhost:8082: footer `Staging · Version 1.0.1`. The build's status text reads `Deployed 1.0.1 to Staging`.
4. **Deploy to Production** > **Run**. Then open http://localhost:8083.
5. Do the whole [demo](demo-guide.md) once as a dry run, then reset (see the end of the demo guide).

## Checklist

- [ ] Visual Studio / Build Tools: MSBuild, web build tools, **.NET SDK** component, .NET 4.8 targeting pack
- [ ] Git for Windows on the agent PC
- [ ] IIS with ASP.NET 4.8; three sites on 8081, 8082, 8083, all started
- [ ] TeamCity server running on 8111; agent connected and authorized
- [ ] Repo pushed with `main` and both `demo/*` branches
- [ ] `settings.kts`: `version` = server version, `demo.repo.url` = repo URL
- [ ] Project created **from the repository URL** and settings imported
- [ ] Two tokens generated and pasted as `apiKeyToken`
- [ ] First run green on all four builds; all three sites show **90.00**
- [ ] Optional: limit who can run **Deploy to Production** (project roles), Notifications build feature

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Import fails: DSL version / "unresolved reference" | `version` in `settings.kts` does not match the server | Set it to the version TeamCity shows, commit, push |
| Build stays **queued** with "no compatible agents" | Agent not authorized, or not Windows | **Agents** > authorize; check the build's **Agent Requirements** |
| Check tools: "MSBuild cannot build SDK-style projects" | .NET SDK component missing in Build Tools | Step 1 |
| Check tools: "Microsoft.WebApplication.targets not found" | Web build tools workload missing | Step 1 |
| Build: `CSC : error CS0006: Metadata file '...systemprofile\.nuget\packages\microsoft.netframework.referenceassemblies...' could not be found` | 32-bit `MSBuild.exe` run as SYSTEM restored the package into `C:\Windows\SysWOW64\config\systemprofile`, but the 64-bit compiler looks in `System32` | Use the 64-bit `MSBuild\Current\Bin\amd64\MSBuild.exe` (`Get-MSBuildPath` in `scripts/common.ps1` now prefers it) |
| Restore fails with 401/403 or a timeout | Agent cannot reach nuget.org (proxy, firewall) | Allow outbound HTTPS to `api.nuget.org` |
| Deploy: "Access to the path ... is denied" | Agent service account cannot write to `C:\inetpub\cicd-demo-*` | Run the agent as SYSTEM, or `icacls C:\inetpub\cicd-demo-* /grant "<user>:(OI)(CI)M"` |
| Deploy: "ApiKey for Staging is empty" | Token not set | Step 6 |
| Deploy: "Expected exactly one DemoApp.Web.*.zip" | CI build had no artifact (it failed), or a bad dependency | Run a green CI build first |
| Smoke test: "Unable to connect" | IIS site or app pool stopped, wrong port | IIS Manager > start the site and app pool; check `site.*.url` |
| Smoke test: HTTP 500 `FAIL <version>` | The app's core logic is wrong (the health check runs it) | Look at the CI build that produced it; roll back |
| Site shows "Deploying a new version" forever | A deploy failed during the copy and left `app_offline.htm` on purpose | Fix the cause (usually a locked file), re-run the deploy or roll back |
| Deploy to Staging did not start after CI | CI failed, or ran on a non-default branch | Only green `main` builds trigger Staging |
