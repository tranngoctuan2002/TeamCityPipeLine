import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.XmlReport
import jetbrains.buildServer.configs.kotlin.buildFeatures.xmlReport
import jetbrains.buildServer.configs.kotlin.buildSteps.powerShell
import jetbrains.buildServer.configs.kotlin.triggers.finishBuildTrigger
import jetbrains.buildServer.configs.kotlin.triggers.vcs
import jetbrains.buildServer.configs.kotlin.vcs.GitVcsRoot

/*
 * CI/CD demo kit: today's pipeline next to the improved pipeline.
 *
 * 1. Current pipeline (today)  -> one build, 7 steps, copies straight to the site folder
 * 2. Improved pipeline         -> CI build (test, gate, versioned artifact) + deploy builds
 *
 * Set `version` to the DSL version your TeamCity server shows under
 * Administration > Projects > <project> > Versioned Settings (e.g. "2024.03", "2024.12", "2025.03").
 */
version = "2024.03"

project {
    description = "CI/CD demo: today's pipeline next to the improved pipeline"

    vcsRoot(DemoRepo)

    params {
        param("demo.repo.url", "https://github.com/your-org/cicd-demo-kit.git")

        // IIS site folders and URLs (see README: one IIS site per pipeline/environment)
        param("site.current.path", """C:\inetpub\cicd-demo-current""")
        param("site.current.url", "http://localhost:8081")
        param("site.staging.path", """C:\inetpub\cicd-demo-staging""")
        param("site.staging.url", "http://localhost:8082")
        param("site.production.path", """C:\inetpub\cicd-demo-production""")
        param("site.production.url", "http://localhost:8083")
    }

    subProject(CurrentPipeline)
    subProject(ImprovedPipeline)
}

object DemoRepo : GitVcsRoot({
    name = "cicd-demo-kit"
    url = "%demo.repo.url%"
    branch = "refs/heads/main"
    branchSpec = "+:refs/heads/*"
})

// ---------------------------------------------------------------------------
// 1. CURRENT PIPELINE: mirrors today's 7 steps, problems included on purpose
// ---------------------------------------------------------------------------

object CurrentPipeline : Project({
    name = "1. Current pipeline (today)"
    description = "Today's 7 steps: no tests, no versioned artifact, no check after deploy"

    buildType(CurrentBuildAndCopy)
})

object CurrentBuildAndCopy : BuildType({
    name = "Build and copy to server"

    vcs {
        root(DemoRepo)
    }

    steps {
        powerShell {
            name = "1. Check the tool"
            scriptMode = file { path = "scripts/check-tools.ps1" }
        }
        powerShell {
            name = "2. Detect code changes"
            scriptMode = file { path = "scripts/detect-changes.ps1" }
            scriptArgs = "-ChangedFilesFile \"%system.teamcity.build.changedFiles.file%\""
        }
        powerShell {
            name = "3. Install NuGet"
            scriptMode = file { path = "scripts/restore.ps1" }
        }
        powerShell {
            name = "4. Build with MSBuild"
            scriptMode = file { path = "scripts/build.ps1" }
            scriptArgs = "-Configuration Release"
        }
        powerShell {
            name = "5. Copy config"
            scriptMode = file { path = "scripts/current/copy-config.ps1" }
        }
        powerShell {
            name = "6. Copy artifact to hosting server"
            scriptMode = file { path = "scripts/current/copy-to-server.ps1" }
            scriptArgs = "-TargetPath \"%site.current.path%\""
        }
        powerShell {
            name = "7. Finish"
            scriptMode = script {
                content = "Write-Host 'Finished: files copied to %site.current.path%'"
            }
        }
    }

    triggers {
        vcs {
            branchFilter = "+:<default>"
        }
    }

    requirements {
        contains("teamcity.agent.jvm.os.name", "Windows")
    }
})

// ---------------------------------------------------------------------------
// 2. IMPROVED PIPELINE: CI build -> Deploy to Staging (auto) -> Deploy to Production (manual)
// ---------------------------------------------------------------------------

object ImprovedPipeline : Project({
    name = "2. Improved pipeline"
    description = "Build once, test, gate, deploy the same versioned artifact everywhere"

    buildType(ImprovedCi)
    buildType(DeployStaging)
    buildType(DeployProduction)

    buildTypesOrder = arrayListOf(ImprovedCi, DeployStaging, DeployProduction)
})

object ImprovedCi : BuildType({
    name = "CI build"
    description = "Every push: check tools, restore, build + version, unit tests, quality gate, publish artifact"

    // Every build gets a version; the same number is stamped into the app and the artifact name.
    buildNumberPattern = "1.0.%build.counter%"

    // Step 6 "Publish artifact": one versioned zip, published only when every step passed.
    artifactRules = "out/publish/** => DemoApp.Web.%build.number%.zip"
    publishArtifacts = PublishMode.SUCCESSFUL

    vcs {
        root(DemoRepo)
        cleanCheckout = true
    }

    steps {
        powerShell {
            name = "1. Check tools"
            scriptMode = file { path = "scripts/check-tools.ps1" }
        }
        powerShell {
            name = "2. Restore NuGet"
            scriptMode = file { path = "scripts/restore.ps1" }
        }
        powerShell {
            name = "3. Build + version"
            scriptMode = file { path = "scripts/build.ps1" }
            scriptArgs = "-Configuration Release -Version %build.number%"
        }
        powerShell {
            name = "4. Unit tests"
            scriptMode = file { path = "scripts/test.ps1" }
            scriptArgs = "-Configuration Release"
        }
        powerShell {
            name = "5. Quality gate"
            scriptMode = file { path = "scripts/quality-gate.ps1" }
        }
    }

    features {
        // Shows the results of scripts/test.ps1 on the Tests tab.
        xmlReport {
            reportType = XmlReport.XmlReportType.VSTEST
            rules = "TestResults/*.trx"
        }
    }

    triggers {
        vcs {
            // Widen to "+:*" (and add the Pull Requests build feature) to build every branch and PR.
            branchFilter = "+:<default>"
        }
    }

    requirements {
        contains("teamcity.agent.jvm.os.name", "Windows")
    }
})

// Secrets: one per environment. Generate a token in Versioned Settings > Tokens and paste
// "credentialsJSON:<token>" below. Never commit the real value. Empty = the deploy fails.
object DeployStaging : DeployBuild(
    envName = "Staging",
    sitePathParam = "site.staging.path",
    siteUrlParam = "site.staging.url",
    apiKeyToken = "",
    deployAutomatically = true
)

object DeployProduction : DeployBuild(
    envName = "Production",
    sitePathParam = "site.production.path",
    siteUrlParam = "site.production.url",
    apiKeyToken = "",
    deployAutomatically = false // manual run = the approval step
)

/**
 * A deploy build never compiles anything: it takes the artifact of a CI build,
 * applies this environment's configuration, deploys it, and checks the site.
 * Rollback = run this build again and pick an older CI build on the Dependencies tab.
 */
open class DeployBuild(
    envName: String,
    sitePathParam: String,
    siteUrlParam: String,
    apiKeyToken: String,
    deployAutomatically: Boolean
) : BuildType({
    id("Deploy$envName")
    name = "Deploy to $envName"
    type = BuildTypeSettings.Type.DEPLOYMENT
    maxRunningBuilds = 1

    params {
        password("env.DEMO_API_KEY", apiKeyToken)
    }

    vcs {
        root(DemoRepo) // only for the deploy scripts, at the same revision as the artifact
    }

    steps {
        powerShell {
            name = "7 + 8. Config per environment, deploy the artifact"
            scriptMode = file { path = "scripts/deploy.ps1" }
            scriptArgs = "-ArtifactDir artifact -TargetPath \"%$sitePathParam%\" -Environment $envName"
        }
        powerShell {
            name = "9. Smoke test"
            scriptMode = file { path = "scripts/smoke-test.ps1" }
            scriptArgs = "-Url %$siteUrlParam%"
        }
        powerShell {
            // Shows in the build status; add the Notifications build feature for Slack/Teams/email.
            name = "10. Set build status"
            scriptMode = file { path = "scripts/set-status.ps1" }
            scriptArgs = "-Environment $envName"
        }
    }

    if (deployAutomatically) {
        triggers {
            finishBuildTrigger {
                buildType = "${ImprovedCi.id}"
                successfulOnly = true
                branchFilter = "+:<default>"
            }
        }
    }

    dependencies {
        dependency(ImprovedCi) {
            snapshot {
                onDependencyFailure = FailureAction.FAIL_TO_START
            }
            artifacts {
                // Clean: a zip left from an earlier run must never be the one deployed (rollback!).
                cleanDestination = true
                artifactRules = "DemoApp.Web.*.zip => artifact"
            }
        }
    }

    requirements {
        contains("teamcity.agent.jvm.os.name", "Windows")
    }
})
