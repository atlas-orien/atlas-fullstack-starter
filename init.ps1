param(
    [Parameter(Position = 0)]
    [string]$ProjectName,

    [Parameter(Position = 1)]
    [string]$OutputDir = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

$InvocationPath = $MyInvocation.MyCommand.Path
$ScriptDir = if ([string]::IsNullOrWhiteSpace($InvocationPath)) { $null } else { Split-Path -Parent $InvocationPath }
$StarterRepoDefault = 'https://github.com/atlas-form/atlas-fullstack-starter.git'
$StarterRefDefault = 'main'
$BackendSourceDefault = 'https://github.com/atlas-form/db-center-template.git'
$BackendRefDefault = 'main'
$FrontendSourceDefault = 'https://github.com/atlas-form/react-mono-template.git'
$FrontendRefDefault = 'main'

function Show-Usage {
@"
Usage:
  .\init.ps1 <project-name> [output-dir]

Examples:
  .\init.ps1 my-app
  .\init.ps1 my-app D:\workspace

Optional environment variables:
  STARTER_REPO     Starter repository URL for pulling project_template remotely
  STARTER_REF      Starter repository branch/ref
  BACKEND_SOURCE   Backend template source (git URL or local path)
  BACKEND_REF      Backend branch/tag/commit (effective only for git source)
  FRONTEND_SOURCE  Frontend template source (git URL or local path)
  FRONTEND_REF     Frontend branch/tag/commit (effective only for git source)
"@
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Test-GitUrl {
    param([string]$Value)

    return $Value -match '^(http://|https://|git@|ssh://)'
}

function Invoke-NativeCommand {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage
    )

    $global:LASTEXITCODE = 0
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage Exit code: $LASTEXITCODE"
    }
}

function Invoke-GitClone {
    param(
        [string]$RepoUrl,
        [string]$RepoRef,
        [string]$TargetDir
    )

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if (Test-Path -LiteralPath $TargetDir) {
            Remove-Item -LiteralPath $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        $global:LASTEXITCODE = 0
        git clone --depth 1 --branch $RepoRef $RepoUrl $TargetDir
        if ($LASTEXITCODE -eq 0) {
            return
        }

        if ($attempt -eq $maxAttempts) {
            throw "Failed to clone repository after $maxAttempts attempts: $RepoUrl"
        }

        Write-Host "    Clone failed, retrying ($attempt/$maxAttempts)..."
        Start-Sleep -Seconds (2 * $attempt)
    }
}

function New-TempDirectory {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("atlas-fullstack-starter." + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

function Copy-DirectoryContents {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string[]]$ExcludeNames = @()
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        throw "Directory not found: $SourceDir"
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        if ($ExcludeNames -contains $_.Name) {
            return
        }

        $destination = Join-Path $TargetDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
    }
}

function Copy-GitRepo {
    param(
        [string]$RepoUrl,
        [string]$RepoRef,
        [string]$TmpDir,
        [string]$TargetDir
    )

    Invoke-GitClone -RepoUrl $RepoUrl -RepoRef $RepoRef -TargetDir $TmpDir
    Copy-DirectoryContents -SourceDir $TmpDir -TargetDir $TargetDir -ExcludeNames @('.git')
}

function Generate-BackendWithCargoGenerate {
    param(
        [string]$Source,
        [string]$Ref,
        [string]$DestinationDir
    )

    Require-Command 'cargo-generate'
    $parentDir = Split-Path -Parent $DestinationDir
    $backendName = Split-Path -Leaf $DestinationDir
    New-Item -ItemType Directory -Force -Path $parentDir | Out-Null

    if (Test-GitUrl $Source) {
        Invoke-NativeCommand -ErrorMessage "Failed to generate backend template from git: $Source" -Command {
            cargo generate --git $Source --branch $Ref --destination $parentDir --name $backendName --silent --vcs none
        }
    } else {
        Invoke-NativeCommand -ErrorMessage "Failed to generate backend template from path: $Source" -Command {
            cargo generate --path $Source --destination $parentDir --name $backendName --silent --vcs none
        }
    }
}

function Copy-FrontendTemplate {
    param(
        [string]$Source,
        [string]$Ref,
        [string]$TmpDir,
        [string]$TargetDir
    )

    Write-Host '==> Prepare frontend template'
    Write-Host "    Source: $Source"

    if (Test-GitUrl $Source) {
        Write-Host "    Ref: $Ref"
        Copy-GitRepo -RepoUrl $Source -RepoRef $Ref -TmpDir $TmpDir -TargetDir $TargetDir
    } else {
        Copy-DirectoryContents -SourceDir $Source -TargetDir $TargetDir -ExcludeNames @('.git', 'node_modules', 'target', 'dist', '.turbo', 'logs', 'tmp', '.DS_Store')
    }
}

function Resolve-TemplateSource {
    param(
        [string]$StarterRepo,
        [string]$StarterRef,
        [string]$StarterTmpDir
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptDir)) {
        $localTemplateDir = Join-Path $ScriptDir 'project_template'
        $localReadmeTpl = Join-Path $localTemplateDir 'ROOT_README.md.tpl'

        if ((Test-Path -LiteralPath $localTemplateDir -PathType Container) -and (Test-Path -LiteralPath $localReadmeTpl -PathType Leaf)) {
            return $localTemplateDir
        }
    }

    Invoke-GitClone -RepoUrl $StarterRepo -RepoRef $StarterRef -TargetDir $StarterTmpDir
    return (Join-Path $StarterTmpDir 'project_template')
}

function Copy-ProjectTemplate {
    param(
        [string]$TemplateSourceDir,
        [string]$ProjectDir
    )

    if (-not (Test-Path -LiteralPath $TemplateSourceDir -PathType Container)) {
        throw "Template directory not found: $TemplateSourceDir"
    }

    Copy-DirectoryContents -SourceDir $TemplateSourceDir -TargetDir $ProjectDir
}

function Replace-InFile {
    param(
        [string]$Path,
        [hashtable]$Map
    )

    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($key in $Map.Keys) {
        $content = $content.Replace($key, $Map[$key])
    }
    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
}

function Merge-ApiDocs {
    param(
        [string]$ProjectDir,
        [string]$BackendDir
    )

    $backendApiDir = Join-Path $BackendDir 'API_CONTRACTS'
    $rootApiDir = Join-Path $ProjectDir 'API_DOCS'

    if (-not (Test-Path -LiteralPath $backendApiDir -PathType Container)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $rootApiDir | Out-Null
    Copy-DirectoryContents -SourceDir $backendApiDir -TargetDir $rootApiDir
    Remove-Item -LiteralPath $backendApiDir -Recurse -Force

    $backendMap = @{
        'API_CONTRACTS/' = '../API_DOCS/'
        'API_CONTRACTS'  = '../API_DOCS'
    }
    Get-ChildItem -LiteralPath $BackendDir -Recurse -File -Filter '*.md' | ForEach-Object {
        Replace-InFile -Path $_.FullName -Map $backendMap
    }

    $rootMap = @{
        'API_CONTRACTS/' = 'API_DOCS/'
        'API_CONTRACTS'  = 'API_DOCS'
    }
    Get-ChildItem -LiteralPath $rootApiDir -Recurse -File -Filter '*.md' | ForEach-Object {
        Replace-InFile -Path $_.FullName -Map $rootMap
    }
}

function Render-RootReadme {
    param(
        [string]$ProjectDir,
        [string]$ProjectNameValue
    )

    $templatePath = Join-Path $ProjectDir 'ROOT_README.md.tpl'
    $readmePath = Join-Path $ProjectDir 'README.md'

    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw 'Missing ROOT_README.md.tpl template'
    }

    $map = @{
        '__PROJECT_NAME__'     = $ProjectNameValue
        '__MANAGE_ENTRY__'     = 'cargo manage'
        '__MANAGE_DESC__'      = '跨平台管理前后端服务的 Rust CLI'
        '__MANAGE_CMD__'       = 'cargo manage'
        '__MANAGE_CODE_LANG__' = 'powershell'
    }
    Replace-InFile -Path $templatePath -Map $map
    Move-Item -LiteralPath $templatePath -Destination $readmePath -Force
}

function Remove-LegacyManageScripts {
    param([string]$ProjectDir)

    Remove-Item -LiteralPath (Join-Path $ProjectDir 'manage.sh') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ProjectDir 'manage.ps1') -Force -ErrorAction SilentlyContinue
}

function Write-RootGitignore {
    param([string]$ProjectDir)

    $content = @"
.DS_Store
.idea/
.vscode/
.claude/
.serena/

output/
temp/
target/
"@

    Set-Content -LiteralPath (Join-Path $ProjectDir '.gitignore') -Value $content -Encoding UTF8
}

function Remove-GeneratedArtifacts {
    param([string]$ProjectDir)

    $targets = @('.git', 'node_modules', 'target', 'logs', 'dist', '.turbo', 'tmp')
    foreach ($name in $targets) {
        Get-ChildItem -LiteralPath $ProjectDir -Force -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $name } |
            Sort-Object FullName -Descending |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem -LiteralPath $ProjectDir -Force -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq '.DS_Store' } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    Show-Usage
    exit 1
}

if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    throw "Invalid project name: $ProjectName. Allowed: letters, digits, dot, underscore, hyphen."
}

Require-Command 'git'

$StarterRepo = if ($env:STARTER_REPO) { $env:STARTER_REPO } else { $StarterRepoDefault }
$StarterRef = if ($env:STARTER_REF) { $env:STARTER_REF } else { $StarterRefDefault }
$BackendSource = if ($env:BACKEND_SOURCE) { $env:BACKEND_SOURCE } else { $BackendSourceDefault }
$BackendRef = if ($env:BACKEND_REF) { $env:BACKEND_REF } else { $BackendRefDefault }
$FrontendSource = if ($env:FRONTEND_SOURCE) { $env:FRONTEND_SOURCE } else { $FrontendSourceDefault }
$FrontendRef = if ($env:FRONTEND_REF) { $env:FRONTEND_REF } else { $FrontendRefDefault }

$TargetDir = Join-Path $OutputDir $ProjectName
$BackendDir = Join-Path $TargetDir 'backend'
$FrontendDir = Join-Path $TargetDir 'frontend'
$TmpDir = New-TempDirectory
$TmpFrontendDir = Join-Path $TmpDir 'frontend'
$TmpStarterDir = Join-Path $TmpDir 'starter'
$ProjectDirCreated = $false

try {
    if (Test-Path -LiteralPath $TargetDir) {
        throw "Target directory already exists: $TargetDir"
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    $ProjectDirCreated = $true

    Write-Host '==> Generate backend template'
    Write-Host "    Source: $BackendSource"
    if (Test-GitUrl $BackendSource) {
        Write-Host "    Ref: $BackendRef"
    }
    Generate-BackendWithCargoGenerate -Source $BackendSource -Ref $BackendRef -DestinationDir $BackendDir

    Copy-FrontendTemplate -Source $FrontendSource -Ref $FrontendRef -TmpDir $TmpFrontendDir -TargetDir $FrontendDir

    Write-Host '==> Copy project template'
    $templateSourceDir = Resolve-TemplateSource -StarterRepo $StarterRepo -StarterRef $StarterRef -StarterTmpDir $TmpStarterDir
    Copy-ProjectTemplate -TemplateSourceDir $templateSourceDir -ProjectDir $TargetDir

    Write-Host '==> Merge API docs to root'
    Merge-ApiDocs -ProjectDir $TargetDir -BackendDir $BackendDir

    Write-Host '==> Render root README and .gitignore'
    Render-RootReadme -ProjectDir $TargetDir -ProjectNameValue $ProjectName
    Write-RootGitignore -ProjectDir $TargetDir
    Remove-LegacyManageScripts -ProjectDir $TargetDir

    Write-Host '==> Clean generated artifacts'
    Remove-GeneratedArtifacts -ProjectDir $TargetDir

    Write-Host '==> Initialize new git repository'
    try {
        git -C $TargetDir init -b main | Out-Null
    } catch {
        git -C $TargetDir init | Out-Null
        try {
            git -C $TargetDir branch -M main | Out-Null
        } catch {
        }
    }

    Write-Host ''
    Write-Host "Initialization completed: $TargetDir"
    Write-Host 'Project is now a fresh git repository.'
    Write-Host 'Template .git directories are not preserved in the generated project.'
    Write-Host ''
    Write-Host 'Directory structure:'
    Write-Host "  $TargetDir/"
    Write-Host '  |- temp/'
    Write-Host '  |- API_DOCS/'
    Write-Host '  |- frontend/'
    Write-Host '  |- backend/'
    Write-Host '  |- deploy/'
    Write-Host '  |- manager/'
    Write-Host '  |- AGENTS.md'
    Write-Host '  |- README.md'
    Write-Host '  |- docker-compose.yml'
    Write-Host '  |- .dockerignore'
    Write-Host '  |- .cargo/'
    Write-Host '  |- AI_PROTOCOLS/'
    Write-Host '  `- .gitignore'
}
catch {
    if ($ProjectDirCreated -and (Test-Path -LiteralPath $TargetDir)) {
        Write-Host "Initialization failed. Removing partial project directory: $TargetDir"
        Remove-Item -LiteralPath $TargetDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $TmpDir) {
        Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
