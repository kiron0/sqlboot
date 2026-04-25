param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerPath,

  [Parameter(Mandatory = $true)]
  [string]$CommandName,

  [string[]]$CommandArgs = @()
)

$ErrorActionPreference = 'Stop'

$SqlbootEnvNames = @(
  'SQLBOOT_ORACLE_PASSWORD',
  'SQLBOOT_ORACLE_IMAGE',
  'SQLBOOT_ORACLE_CONTAINER',
  'SQLBOOT_ORACLE_PORT',
  'SQLBOOT_ORACLE_SERVICE',
  'SQLBOOT_IC_BASIC_URL',
  'SQLBOOT_IC_SQLPLUS_URL',
  'SQLBOOT_READY_TIMEOUT_SECONDS',
  'SQLBOOT_DOCKER_READY_TIMEOUT_SECONDS',
  'SQLBOOT_ORACLE_BASE_DIR',
  'SQLBOOT_INSTANTCLIENT_PARENT',
  'SQLBOOT_SQLPLUS_HISTORY'
)

$script:LastWslListError = ''
$script:RestartRequired = $false
$script:LastDockerInfoError = ''
$script:LastWslCommandError = ''

function Test-PurgeRequested {
  return $CommandName -eq 'uninstall' -and ($CommandArgs -contains '--purge')
}

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Write-Ok {
  param([string]$Message)
  Write-Host "[OK] $Message"
}

function Write-Fail {
  param([string]$Message)
  [Console]::Error.WriteLine("[ERROR] $Message")
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-DockerExe {
  $command = Get-Command 'docker.exe' -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidates = @(@(
    "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\resources\bin\docker.exe",
    "$env:LOCALAPPDATA\Docker\resources\bin\docker.exe"
  ) | Where-Object { $_ -and (Test-Path $_) })

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  return $null
}

function Get-UbuntuLauncher {
  $commands = @('ubuntu.exe', 'ubuntu2404.exe', 'ubuntu2204.exe', 'ubuntu2004.exe')
  foreach ($commandName in $commands) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
  $candidates = @(@(
    'ubuntu.exe',
    'ubuntu2404.exe',
    'ubuntu2204.exe',
    'ubuntu2004.exe'
  ) | ForEach-Object { Join-Path $windowsApps $_ } | Where-Object { Test-Path $_ })

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }

  return $null
}

function Invoke-ElevatedPowerShell {
  param([string]$Command)

  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
  $process = Start-Process powershell.exe `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) `
    -Verb RunAs `
    -Wait `
    -PassThru

  if ($process.ExitCode -eq 3010) {
    $script:RestartRequired = $true
    return
  }

  if ($process.ExitCode -ne 0) {
    throw "Elevated command failed with exit code $($process.ExitCode)."
  }
}

function Enable-WslOptionalFeatures {
  Write-Info 'Enabling Windows WSL2 optional features. Windows may ask for administrator approval.'
  Invoke-ElevatedPowerShell @'
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { exit $LASTEXITCODE }
$restartRequired = $LASTEXITCODE -eq 3010
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { exit $LASTEXITCODE }
if ($LASTEXITCODE -eq 3010) { $restartRequired = $true }
if ($restartRequired) { exit 3010 }
'@
}

function Disable-WslOptionalFeatures {
  Write-Info 'Disabling Windows WSL optional features. Windows may ask for administrator approval.'
  Invoke-ElevatedPowerShell @'
$ErrorActionPreference = 'Stop'
& wsl.exe --shutdown 2>$null
$restartRequired = $false

$capabilities = Get-WindowsCapability -Online |
  Where-Object {
    ($_.Name -like 'Microsoft.Windows.Subsystem.Linux*' -or $_.Name -like 'Microsoft.WindowsSubsystemForLinux*') -and
    $_.State -eq 'Installed'
  }
foreach ($capability in $capabilities) {
  $result = Remove-WindowsCapability -Online -Name $capability.Name
  if ($result.RestartNeeded) { $restartRequired = $true }
}

$featureResult = Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
if ($featureResult.RestartNeeded) { $restartRequired = $true }
$featureResult = Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
if ($featureResult.RestartNeeded) { $restartRequired = $true }
if ($restartRequired) { exit 3010 }
'@

  if ($script:RestartRequired) {
    Write-Info 'Windows restart required to finish disabling WSL optional features.'
  } else {
    Write-Ok 'Windows WSL optional features disabled'
  }
}

function Add-CurrentUserToDockerUsers {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $existingMember = Get-LocalGroupMember -Group 'docker-users' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq $identity }

  if ($existingMember) {
    Write-Ok "$identity already has Docker Desktop access"
    return
  }

  Write-Info "Granting Docker Desktop access to $identity. Windows may ask for administrator approval."
  $escapedIdentity = $identity.Replace("'", "''")
  Invoke-ElevatedPowerShell @"
`$identity = '$escapedIdentity'
`$group = Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue
if (-not `$group) {
  New-LocalGroup -Name 'docker-users' -Description 'Docker Desktop users' | Out-Null
}
`$member = Get-LocalGroupMember -Group 'docker-users' -ErrorAction SilentlyContinue |
  Where-Object { `$_.Name -ieq `$identity }
if (-not `$member) {
  Add-LocalGroupMember -Group 'docker-users' -Member `$identity -ErrorAction Stop
}
"@
  throw "Docker Desktop access was updated for $identity. Sign out of Windows or restart, then rerun sqlboot init."
}

function Remove-CurrentUserFromDockerUsers {
  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  Write-Info "Removing Docker Desktop access for $identity. Windows may ask for administrator approval."
  $escapedIdentity = $identity.Replace("'", "''")
  Invoke-ElevatedPowerShell @"
`$identity = '$escapedIdentity'
`$group = Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue
if (`$group) {
  `$member = Get-LocalGroupMember -Group 'docker-users' -ErrorAction SilentlyContinue |
    Where-Object { `$_.Name -ieq `$identity }
  if (`$member) {
    Remove-LocalGroupMember -Group 'docker-users' -Member `$identity -ErrorAction SilentlyContinue
  }
}
"@
}

function Restart-WslService {
  Write-Info 'Restarting the Windows WSL service. Windows may ask for administrator approval.'
  Invoke-ElevatedPowerShell @'
wsl.exe --shutdown
Restart-Service LxssManager -Force
'@
}

function Set-DockerDefaultWslIntegration {
  param([string]$Distro)

  $settingsPath = Join-Path $env:APPDATA 'Docker\settings-store.json'
  if (-not (Test-Path $settingsPath)) {
    return
  }

  try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $changed = $false

    if ($settings.PSObject.Properties.Name -contains 'EnableIntegrationWithDefaultWslDistro') {
      if ($settings.EnableIntegrationWithDefaultWslDistro -ne $true) {
        $settings.EnableIntegrationWithDefaultWslDistro = $true
        $changed = $true
      }
    } else {
      $settings | Add-Member -NotePropertyName 'EnableIntegrationWithDefaultWslDistro' -NotePropertyValue $true
      $changed = $true
    }

    if ($Distro) {
      if ($settings.PSObject.Properties.Name -contains 'IntegratedWslDistros') {
        $distros = @($settings.IntegratedWslDistros)
        if ($distros -notcontains $Distro) {
          $settings.IntegratedWslDistros = @($distros + $Distro)
          $changed = $true
        }
      } else {
        $settings | Add-Member -NotePropertyName 'IntegratedWslDistros' -NotePropertyValue @($Distro)
        $changed = $true
      }
    }

    if ($changed) {
      $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
      Write-Ok 'Docker Desktop default WSL integration setting is enabled'
    }
  } catch {
    Write-Info "Could not update Docker Desktop settings automatically: $($_.Exception.Message)"
  }
}

function Disable-DockerDesktopWslIntegration {
  param([string]$Distro)

  Clear-DockerSqlbootIntegration -Distro $Distro
}

function Clear-DockerSqlbootIntegration {
  param([string]$Distro)

  $settingsPath = Join-Path $env:APPDATA 'Docker\settings-store.json'
  if (-not (Test-Path $settingsPath)) {
    return
  }

  try {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $changed = $false

    if ($Distro -and $settings.PSObject.Properties.Name -contains 'IntegratedWslDistros') {
      $distros = @($settings.IntegratedWslDistros) | Where-Object { $_ -ne $Distro }
      $settings.IntegratedWslDistros = @($distros)
      $changed = $true
    }

    if ($settings.PSObject.Properties.Name -contains 'EnableIntegrationWithDefaultWslDistro') {
      $settings.EnableIntegrationWithDefaultWslDistro = $false
      $changed = $true
    }

    if ($changed) {
      $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
      Write-Ok 'Removed sqlboot Docker Desktop WSL integration settings'
    }
  } catch {
    Write-Info "Could not clean Docker Desktop settings automatically: $($_.Exception.Message)"
  }
}

function Test-DockerDesktopReady {
  param([string]$DockerExe)

  $script:LastDockerInfoError = ''
  try {
    $output = & $DockerExe info 2>&1
    if ($LASTEXITCODE -eq 0) {
      return $true
    }

    $script:LastDockerInfoError = (($output | Out-String) -replace "`0", '').Trim()
    return $false
  } catch {
    $script:LastDockerInfoError = $_.Exception.Message
    return $false
  }
}

function Get-WslDistros {
  if (-not (Test-Command 'wsl.exe')) {
    return @()
  }

  $script:LastWslListError = ''
  $raw = & wsl.exe -l -q 2>&1
  if ($LASTEXITCODE -ne 0) {
    $script:LastWslListError = (($raw | Out-String) -replace "`0", '').Trim()
    return @()
  }

  return @(
    $raw |
      ForEach-Object { ($_ -replace "`0", '').Trim() } |
      Where-Object { $_.Length -gt 0 }
  )
}

function Assert-WslHostReady {
  if (-not (Test-Command 'wsl.exe')) {
    return
  }

  $output = & wsl.exe --status 2>&1
  $message = (($output | Out-String) -replace "`0", '').Trim()

  if ($message -match 'Virtual Machine Platform|Windows Subsystem for Linux|optional component') {
    Enable-WslOptionalFeatures
    throw "Windows WSL2 features were enabled. Restart Windows, then rerun sqlboot init. If this message appears again after restart, enable CPU virtualization in BIOS/UEFI."
  }

  if ($message -match 'virtualisation|virtualization|BIOS') {
    throw "WSL2 needs CPU virtualization enabled in BIOS/UEFI. Enable virtualization there, restart Windows, then rerun sqlboot init."
  }

  if ($message -match 'E_ACCESSDENIED|Access is denied') {
    throw "WSL is installed, but Windows is denying access to the WSL service. Restart Windows, then rerun sqlboot init. If it still fails, run PowerShell as Administrator once and run: wsl --update"
  }

  if ($message -match 'restart|reboot') {
    throw "WSL needs a Windows restart before Ubuntu can finish setup. Restart Windows, then rerun sqlboot init."
  }

  if ($LASTEXITCODE -eq 0) {
    return
  }

  if ($message) {
    throw "WSL is not ready yet: $message"
  }
}

function Get-SqlbootDistro {
  $requested = $env:SQLBOOT_WSL_DISTRO
  $distros = Get-WslDistros

  if ($requested) {
    if ($distros -contains $requested) {
      return $requested
    }
    throw "WSL distro '$requested' was requested with SQLBOOT_WSL_DISTRO, but it is not installed."
  }

  $ubuntu = $distros | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1
  if ($ubuntu) {
    return $ubuntu
  }

  if ($distros.Count -gt 0) {
    return $distros[0]
  }

  return $null
}

function Test-WslDistroInitialized {
  param([string]$Distro)

  $script:LastWslCommandError = ''

  if (-not $Distro) {
    return $false
  }

  $output = & wsl.exe -d $Distro -- sh -lc 'id -u >/dev/null 2>&1' 2>&1
  if ($LASTEXITCODE -eq 0) {
    return $true
  }

  $message = (($output | Out-String) -replace "`0", '').Trim()
  $script:LastWslCommandError = $message
  if ($message -match 'not registered|There is no distribution') {
    return $false
  }

  return $false
}

function Assert-WslDistroReachable {
  param([string]$Distro)

  $script:LastWslCommandError = ''
  $output = & wsl.exe -d $Distro -- true 2>&1
  if ($LASTEXITCODE -eq 0) {
    return
  }

  $script:LastWslCommandError = (($output | Out-String) -replace "`0", '').Trim()
  if ($script:LastWslCommandError -match 'E_ACCESSDENIED|Access is denied') {
    Restart-WslService
    throw "WSL access was denied by Windows. The WSL service was restarted. Close Docker Desktop popups, choose 'Restart the WSL integration' if shown, then rerun sqlboot $CommandName."
  }

  throw "WSL distro '$Distro' is not reachable: $script:LastWslCommandError"
}

function Initialize-UbuntuWithoutPrompt {
  $launcher = Get-UbuntuLauncher
  if (-not $launcher) {
    return $false
  }

  Write-Info 'Initializing Ubuntu automatically with the root user'
  & $launcher install --root
  if ($LASTEXITCODE -eq 0) {
    Write-Ok 'Ubuntu initialized automatically'
    return $true
  }

  return $false
}

function Invoke-WslFirstRun {
  param([string]$DistroName = 'Ubuntu')

  if (Test-WslDistroInitialized -Distro $DistroName) {
    Write-Ok "$DistroName is initialized"
    return
  }

  if ($DistroName -like 'Ubuntu*' -and (Initialize-UbuntuWithoutPrompt)) {
    return
  }

  Write-Info "Opening $DistroName first-run setup. Create the Linux username/password when prompted."
  Write-Info "After setup finishes, type 'exit' in Ubuntu and sqlboot will continue automatically."

  $output = & wsl.exe -d $DistroName 2>&1
  if ($LASTEXITCODE -ne 0) {
    $message = (($output | Out-String) -replace "`0", '').Trim()
    if ($message -match 'E_ACCESSDENIED|Access is denied') {
      Restart-WslService
      throw "WSL access was denied while opening $DistroName. The WSL service was restarted. Rerun sqlboot init."
    }

    if ($message -match 'restart|reboot') {
      throw "WSL needs a Windows restart before $DistroName can finish setup. Restart Windows, then rerun sqlboot init."
    }

    Assert-WslHostReady
    throw "$DistroName WSL first-run setup did not complete: $message"
  }

  if (-not (Test-WslDistroInitialized -Distro $DistroName)) {
    throw "$DistroName WSL first-run setup still is not complete. Open $DistroName from the Start menu, create the Linux user, type exit, then rerun sqlboot init."
  }

  Write-Ok "$DistroName is initialized"
}

function Ensure-WslUbuntu {
  if (-not (Test-Command 'wsl.exe')) {
    Write-Info 'WSL command was not found. Installing Windows WSL features. Windows may ask for administrator approval.'
    Enable-WslOptionalFeatures
    throw 'Windows WSL features were installed. Restart Windows, then rerun sqlboot init so SQLBoot can install Ubuntu.'
  }

  Assert-WslHostReady

  $distro = Get-SqlbootDistro
  if (-not $distro -and $script:LastWslListError -match 'E_ACCESSDENIED|Access is denied') {
    Restart-WslService
    throw "WSL access was denied while listing distros. The WSL service was restarted. Rerun sqlboot init."
  }

  if ($distro) {
    if (-not (Test-WslDistroInitialized -Distro $distro)) {
      Invoke-WslFirstRun -DistroName $distro
    }

    Write-Ok "Using WSL distro: $distro"
    return $distro
  }

  Write-Info 'Installing Ubuntu for WSL. Finish any first-run Ubuntu account prompt if Windows opens one.'
  & wsl.exe --install Ubuntu
  if ($LASTEXITCODE -ne 0) {
    & wsl.exe --install -d Ubuntu
  }
  if ($LASTEXITCODE -ne 0) {
    Assert-WslHostReady
    throw 'Ubuntu WSL installation did not complete. Restart Windows if prompted, open Ubuntu once, then rerun sqlboot init.'
  }

  Assert-WslHostReady

  Invoke-WslFirstRun -DistroName 'Ubuntu'

  $distro = Get-SqlbootDistro
  if (-not $distro) {
    if ($script:LastWslListError -match 'E_ACCESSDENIED|Access is denied') {
      throw "WSL is installed, but Windows is denying access to the WSL service. Restart Windows, then rerun sqlboot init. If it still fails, run PowerShell as Administrator once and run: wsl --update"
    }

    throw 'Ubuntu WSL is installed but not initialized yet. Open Ubuntu once to create the Linux user, then rerun sqlboot init.'
  }

  Write-Ok "Using WSL distro: $distro"
  return $distro
}

function Try-EnableDockerWslIntegration {
  param([string]$Distro)

  Write-Info "Preparing Docker access inside WSL distro $Distro"
  Disable-DockerDesktopWslIntegration -Distro $Distro

  Assert-WslDistroReachable -Distro $Distro

$repairScript = @'
set -eu
docker_cli=""
for candidate in \
  "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" \
  "/mnt/c/Program Files/Docker/Docker/resources/bin/com.docker.cli.exe" \
  /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker \
  /mnt/wsl/docker-desktop/docker-cli-tools/usr/bin/docker
do
  if [ -x "$candidate" ] || [ -f "$candidate" ]; then
    docker_cli="$candidate"
    break
  fi
done
if [ -z "$docker_cli" ]; then
  exit 10
fi
mkdir -p /usr/local/bin
escaped_docker_cli="$(printf '%s' "$docker_cli" | sed "s/'/'\\\\''/g")"
docker_cli_dir="$(dirname "$docker_cli")"
escaped_docker_cli_dir="$(printf '%s' "$docker_cli_dir" | sed "s/'/'\\\\''/g")"
{
  printf '%s\n' '#!/bin/sh'
  printf "DOCKER_CLI_DIR='%s'\n" "$escaped_docker_cli_dir"
  printf '%s\n' 'case ":$PATH:" in'
  printf '%s\n' '  *":$DOCKER_CLI_DIR:"*) ;;'
  printf '%s\n' '  *) PATH="$DOCKER_CLI_DIR:$PATH"; export PATH ;;'
  printf '%s\n' 'esac'
  printf "exec '%s' \"\$@\"\n" "$escaped_docker_cli"
} >/usr/local/bin/docker
chmod +x /usr/local/bin/docker
hash -r 2>/dev/null || true
docker info >/dev/null 2>&1
'@

  $script:LastWslCommandError = ''
  if ((Invoke-WslRootScript -Distro $Distro -Script $repairScript -Quiet) -eq 0) {
    Write-Ok "Docker is available inside WSL distro $Distro"
    return $true
  }

  $script:LastWslCommandError = 'Docker proxy setup failed inside WSL.'
  if ($script:LastWslCommandError) {
    Write-Info $script:LastWslCommandError
  }
  return $false
}

function Ensure-DockerDesktop {
  if (Get-DockerExe) {
    Write-Ok 'Docker CLI is available on Windows'
    return
  }

  if (-not (Test-Command 'winget.exe')) {
    throw 'Docker Desktop is not installed and winget is unavailable. Install Docker Desktop, then rerun sqlboot init.'
  }

  Write-Info 'Installing Docker Desktop with winget. Windows may ask for administrator approval.'
  & winget.exe install --id Docker.DockerDesktop --exact --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop installation failed.'
  }
}

function Start-DockerDesktop {
  $dockerExe = Get-DockerExe
  if (-not $dockerExe) {
    throw 'Docker CLI was not found after Docker Desktop installation. Open a new terminal, then rerun sqlboot init.'
  }

  if (Test-DockerDesktopReady -DockerExe $dockerExe) {
    Write-Ok 'Docker Desktop is running'
    return
  }

  if ($script:LastDockerInfoError -match 'permission denied|Access is denied|docker_engine') {
    Add-CurrentUserToDockerUsers
  }

  $desktopProcess = Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($desktopProcess) {
    Write-Info 'Docker Desktop is already open; waiting for it to become ready'
  } else {
    $candidates = @(@(
      "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
      "$env:ProgramFiles\Docker\Docker\frontend\Docker Desktop.exe",
      "$env:ProgramFiles\Docker\Docker\resources\Docker Desktop.exe",
      "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
      "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    ) | Where-Object { $_ -and (Test-Path $_) })

    if ($candidates.Count -gt 0) {
      Write-Info "Starting Docker Desktop: $($candidates[0])"
      Start-Process -FilePath $candidates[0] | Out-Null
    } else {
      Write-Info 'Docker Desktop app was not found in the usual install paths; waiting for Docker engine anyway'
    }
  }

  $timeoutSeconds = 180
  if ($env:SQLBOOT_DOCKER_READY_TIMEOUT_SECONDS) {
    $timeoutSeconds = [int]$env:SQLBOOT_DOCKER_READY_TIMEOUT_SECONDS
  }

  $elapsed = 0
  while ($elapsed -lt $timeoutSeconds) {
    if (Test-DockerDesktopReady -DockerExe $dockerExe) {
      Write-Ok 'Docker Desktop is running'
      return
    }

    if ($script:LastDockerInfoError -match 'permission denied|Access is denied|docker_engine') {
      Add-CurrentUserToDockerUsers
    }

    Start-Sleep -Seconds 3
    $elapsed += 3
  }

  if ($script:LastDockerInfoError) {
    throw "Docker Desktop did not become ready within ${timeoutSeconds}s. Last Docker error: $script:LastDockerInfoError"
  }

  throw "Docker Desktop did not become ready within ${timeoutSeconds}s. Open Docker Desktop, finish first-run setup, then rerun sqlboot $CommandName."
}

function Convert-ToWslPath {
  param(
    [string]$Distro,
    [string]$WindowsPath
  )

  $path = & wsl.exe -d $Distro -- wslpath -a -u $WindowsPath
  if ($LASTEXITCODE -ne 0 -or -not $path) {
    throw "Unable to convert Windows path for WSL: $WindowsPath"
  }

  return ($path | Select-Object -First 1).Trim()
}

function Test-WslDocker {
  param([string]$Distro)

  Assert-WslDistroReachable -Distro $Distro

  $script:LastWslCommandError = ''
  $output = & wsl.exe -d $Distro -- sh -lc 'command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1' 2>&1
  if ($LASTEXITCODE -eq 0) {
    return $true
  }

  $script:LastWslCommandError = (($output | Out-String) -replace "`0", '').Trim()
  return $false
}

function Invoke-WslRootScript {
  param(
    [string]$Distro,
    [string]$Script,
    [switch]$Quiet
  )

  $normalized = $Script -replace "`r`n", "`n"
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($normalized))
  $runner = "printf '%s' '$encoded' | base64 -d | sh"
  $arguments = @('-d', $Distro, '-u', 'root', '--', 'sh', '-lc', $runner)
  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()

  try {
    $process = Start-Process -FilePath 'wsl.exe' `
      -ArgumentList $arguments `
      -NoNewWindow `
      -Wait `
      -PassThru `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath

    if (-not $Quiet) {
      $stdout = Get-Content $stdoutPath -ErrorAction SilentlyContinue
      $stderr = Get-Content $stderrPath -ErrorAction SilentlyContinue

      foreach ($line in $stdout) {
        Write-Host $line
      }

      foreach ($line in $stderr) {
        [Console]::Error.WriteLine($line)
      }
    }

    return [int]$process.ExitCode
  } finally {
    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Ensure-SqlplusRuntimeDepsInWsl {
  param([string]$Distro)

  if ($CommandName -notin @('init', 'start', 'doctor')) {
    return
  }

  Write-Info 'Checking SQL*Plus runtime dependencies in WSL'

  $checkScript = @'
spath="$(find /home/*/oracle/instantclient /root/oracle/instantclient -maxdepth 2 -type f -name sqlplus 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$spath" ]; then
  if LD_LIBRARY_PATH="$(dirname "$spath"):${LD_LIBRARY_PATH:-}" ldd "$spath" 2>/dev/null | grep -Fq "libaio.so.1 => not found"; then
    exit 1
  fi
  exit 0
fi
ldconfig -p 2>/dev/null | grep -Fq libaio.so.1
'@

  if ((Invoke-WslRootScript -Distro $Distro -Script $checkScript -Quiet) -eq 0) {
    Write-Ok 'SQL*Plus runtime dependencies are ready'
    return
  }

  Write-Info 'Installing SQL*Plus runtime dependency libaio in WSL'
  $repairScript = @'
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  installed=0
  for package_name in libaio1t64 libaio1 libaio-dev; do
    if apt-cache show "$package_name" >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name"; then
      installed=1
      break
    fi
  done

  if [ "$installed" = "0" ]; then
    if command -v add-apt-repository >/dev/null 2>&1; then
      add-apt-repository -y universe || true
    else
      DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common && add-apt-repository -y universe || true
    fi
    if [ -d /etc/apt/sources.list.d ]; then
      for source_file in /etc/apt/sources.list.d/*.sources; do
        [ -f "$source_file" ] || continue
        if grep -q '^Components:' "$source_file" && ! grep -q '^Components:.*universe' "$source_file"; then
          sed -i 's/^Components: \(.*\)$/Components: \1 universe/' "$source_file"
        fi
      done
    fi
    apt-get update
    for package_name in libaio1t64 libaio1 libaio-dev; do
      if apt-cache show "$package_name" >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name"; then
        installed=1
        break
      fi
    done
  fi

  if [ "$installed" = "0" ]; then
    arch="$(dpkg --print-architecture 2>/dev/null || true)"
    if [ "$arch" = "amd64" ]; then
      tmp_deb="$(mktemp)"
      deb_url="https://archive.ubuntu.com/ubuntu/pool/main/liba/libaio/libaio1t64_0.3.113-8build1_amd64.deb"
      if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$tmp_deb" "$deb_url" && dpkg -i "$tmp_deb" && installed=1
      elif command -v wget >/dev/null 2>&1; then
        wget -O "$tmp_deb" "$deb_url" && dpkg -i "$tmp_deb" && installed=1
      fi
      rm -f "$tmp_deb"
    fi
  fi

  apt-get clean
  ldconfig
fi

spath="$(find /home/*/oracle/instantclient /root/oracle/instantclient -maxdepth 2 -type f -name sqlplus 2>/dev/null | sort | tail -n 1 || true)"
needs_link=0
if [ -n "$spath" ]; then
  if LD_LIBRARY_PATH="$(dirname "$spath"):${LD_LIBRARY_PATH:-}" ldd "$spath" 2>/dev/null | grep -Fq "libaio.so.1 => not found"; then
    needs_link=1
  fi
elif ! ldconfig -p 2>/dev/null | grep -Fq libaio.so.1; then
  needs_link=1
fi

  if [ "$needs_link" = "1" ]; then
  echo "sqlboot: looking for libaio runtime files" >&2
  candidate="$(find /usr/lib /lib -type f \( -name 'libaio.so.1*' -o -name 'libaio.so.*' \) -print 2>/dev/null | sort | head -n 1 || true)"
  if [ -z "$candidate" ] && command -v apt-get >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture 2>/dev/null || true)"
    if [ "$arch" = "amd64" ]; then
      tmp_dir="$(mktemp -d)"
      deb_path="$tmp_dir/libaio.deb"
      for deb_url in \
        "https://archive.ubuntu.com/ubuntu/pool/main/liba/libaio/libaio1t64_0.3.113-8build1_amd64.deb" \
        "https://archive.ubuntu.com/ubuntu/pool/main/liba/libaio/libaio1_0.3.113-8_amd64.deb" \
        "https://archive.ubuntu.com/ubuntu/pool/main/liba/libaio/libaio1_0.3.112-13build1_amd64.deb" \
        "https://deb.debian.org/debian/pool/main/liba/libaio/libaio1_0.3.113-4_amd64.deb"
      do
        echo "sqlboot: trying libaio package $deb_url" >&2
        rm -f "$deb_path"
        if command -v curl >/dev/null 2>&1; then
          curl -fL --retry 3 -o "$deb_path" "$deb_url" || true
        elif command -v wget >/dev/null 2>&1; then
          wget -O "$deb_path" "$deb_url" || true
        fi
        if [ -s "$deb_path" ]; then
          rm -rf "$tmp_dir/extract"
          mkdir -p "$tmp_dir/extract"
          dpkg-deb -x "$deb_path" "$tmp_dir/extract" || true
          candidate="$(find "$tmp_dir/extract" -type f \( -name 'libaio.so.1*' -o -name 'libaio.so.*' \) -print 2>/dev/null | sort | head -n 1 || true)"
          if [ -n "$candidate" ]; then
            break
          fi
        fi
      done
      if [ -z "$candidate" ] && [ -d "$tmp_dir/extract" ]; then
        echo "sqlboot: extracted package contents did not include libaio; sample files:" >&2
        find "$tmp_dir/extract" -maxdepth 5 -type f | head -n 40 >&2 || true
      fi
      if [ -n "$candidate" ]; then
        echo "sqlboot: extracted libaio candidate $candidate" >&2
        mkdir -p /usr/local/lib
        cp "$candidate" /usr/local/lib/libaio.so.1
        candidate="/usr/local/lib/libaio.so.1"
      fi
      rm -rf "$tmp_dir"
    fi
  fi
  if [ -n "$candidate" ]; then
    echo "sqlboot: linking libaio candidate $candidate" >&2
    ln -sf "$candidate" /usr/local/lib/libaio.so.1
    if [ -n "$spath" ]; then
      ln -sf "$candidate" "$(dirname "$spath")/libaio.so.1"
    fi
    ldconfig
  fi
fi

if [ -n "$spath" ]; then
  if LD_LIBRARY_PATH="$(dirname "$spath"):${LD_LIBRARY_PATH:-}" ldd "$spath" 2>/dev/null | grep -Fq "libaio.so.1 => not found"; then
    echo "sqlboot: libaio.so.1 is still missing for $spath" >&2
    echo "sqlboot: installed libaio packages:" >&2
    dpkg -l | grep -E 'libaio|libc6' >&2 || true
    echo "sqlboot: libaio files found:" >&2
    find /usr/lib /lib /usr/local/lib "$(dirname "$spath")" -name 'libaio.so*' -print -exec ls -l {} \; 2>/dev/null >&2 || true
    exit 1
  fi
  exit 0
fi

if ! ldconfig -p 2>/dev/null | grep -Fq libaio.so.1; then
  echo "sqlboot: libaio.so.1 is not visible to ldconfig" >&2
  dpkg -l | grep -E 'libaio|libc6' >&2 || true
  find /usr/lib /lib /usr/local/lib -name 'libaio.so*' -print -exec ls -l {} \; 2>/dev/null >&2 || true
  exit 1
fi
'@

  if ((Invoke-WslRootScript -Distro $Distro -Script $repairScript) -ne 0) {
    throw "Could not install SQL*Plus runtime dependency libaio inside WSL distro '$Distro'."
  }

  Write-Ok 'SQL*Plus runtime dependencies are ready'
}

function Invoke-SqlbootInWsl {
  param(
    [string]$Distro,
    [string]$WslInstallerPath
  )

  $envArgs = @()
  foreach ($name in $SqlbootEnvNames) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($null -ne $value -and $value.Length -gt 0) {
      $envArgs += "$name=$value"
    }
  }

  $args = @('-d', $Distro, '--', 'env') + $envArgs + @('bash', $WslInstallerPath, $CommandName) + $CommandArgs
  & wsl.exe @args
  exit $LASTEXITCODE
}

function Invoke-SqlbootInWslNoExit {
  param(
    [string]$Distro,
    [string]$WslInstallerPath,
    [string[]]$InstallerArgs
  )

  $envArgs = @()
  foreach ($name in $SqlbootEnvNames) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($null -ne $value -and $value.Length -gt 0) {
      $envArgs += "$name=$value"
    }
  }

  $args = @('-d', $Distro, '--', 'env') + $envArgs + @('bash', $WslInstallerPath) + $InstallerArgs
  & wsl.exe @args 2>&1 | ForEach-Object {
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
      [Console]::Error.WriteLine($_.ToString())
    } else {
      [Console]::Out.WriteLine($_)
    }
  }
  return [int]$LASTEXITCODE
}

function Uninstall-DockerDesktop {
  Write-Info 'Removing Docker Desktop'

  if (Test-Command 'winget.exe') {
    & winget.exe uninstall --id Docker.DockerDesktop --exact --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
      Write-Ok 'Docker Desktop removed'
      return
    }
  }

  $uninstallers = @(@(
    "$env:ProgramFiles\Docker\Docker\Docker Desktop Installer.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop Installer.exe"
  ) | Where-Object { $_ -and (Test-Path $_) })

  if ($uninstallers.Count -gt 0) {
    & $uninstallers[0] uninstall --quiet
    if ($LASTEXITCODE -eq 0) {
      Write-Ok 'Docker Desktop removed'
      return
    }
  }

  Write-Info 'Docker Desktop could not be removed automatically. Remove it from Windows Settings > Apps if you no longer need it.'
}

function Uninstall-WindowsPackageByWingetId {
  param(
    [string]$PackageId,
    [string]$DisplayName
  )

  if (-not (Test-Command 'winget.exe')) {
    return
  }

  Write-Info "Removing $DisplayName with winget"
  & winget.exe uninstall --id $PackageId --exact --accept-source-agreements
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "$DisplayName removed"
  }
}

function Uninstall-UbuntuAppPackages {
  Write-Info 'Removing Ubuntu WSL app packages'

  $ubuntuWingetIds = @(
    'Canonical.Ubuntu',
    'Canonical.Ubuntu.2404',
    'Canonical.Ubuntu.2204',
    'Canonical.Ubuntu.2004'
  )

  foreach ($packageId in $ubuntuWingetIds) {
    Uninstall-WindowsPackageByWingetId -PackageId $packageId -DisplayName $packageId
  }

  $appxPackages = Get-AppxPackage |
    Where-Object { $_.Name -like 'CanonicalGroupLimited.Ubuntu*' -or $_.PackageFamilyName -like 'CanonicalGroupLimited.Ubuntu*' }

  foreach ($package in $appxPackages) {
    Write-Info "Removing Appx package $($package.Name)"
    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
  }
}

function Uninstall-WslAppPackage {
  Write-Info 'Removing Windows Subsystem for Linux app package where present'

  Uninstall-WindowsPackageByWingetId -PackageId 'Microsoft.WSL' -DisplayName 'Windows Subsystem for Linux'

  Invoke-ElevatedPowerShell @'
$packages = Get-AppxPackage -AllUsers |
  Where-Object { $_.Name -eq 'MicrosoftCorporationII.WindowsSubsystemForLinux' -or $_.PackageFamilyName -like 'MicrosoftCorporationII.WindowsSubsystemForLinux*' }
foreach ($package in $packages) {
  Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
}

$provisionedPackages = Get-AppxProvisionedPackage -Online |
  Where-Object { $_.DisplayName -eq 'MicrosoftCorporationII.WindowsSubsystemForLinux' -or $_.PackageName -like 'MicrosoftCorporationII.WindowsSubsystemForLinux*' }
foreach ($package in $provisionedPackages) {
  Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName | Out-Null
}
'@

  $wslPackages = Get-AppxPackage |
    Where-Object { $_.Name -eq 'MicrosoftCorporationII.WindowsSubsystemForLinux' -or $_.PackageFamilyName -like 'MicrosoftCorporationII.WindowsSubsystemForLinux*' }

  foreach ($package in $wslPackages) {
    Write-Info "Removing Appx package $($package.Name)"
    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
  }
}

function Unregister-WslDistro {
  param([string]$Distro)

  if (-not $Distro) {
    return
  }

  Write-Info "Unregistering WSL distro: $Distro"
  & wsl.exe --unregister $Distro
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "Removed WSL distro: $Distro"
  } else {
    Write-Info "Could not unregister WSL distro '$Distro'. Remove it manually with: wsl --unregister $Distro"
  }
}

function Run-WindowsPurge {
  param(
    [string]$Distro,
    [string]$WslInstallerPath
  )

  Write-Info 'Running normal sqlboot uninstall before Windows purge'
  Write-Info "Ubuntu may ask for your Linux sudo password while removing /usr/local/bin/sqlboot."
  Write-Info 'If a password prompt appears, type the Ubuntu password you created during WSL setup.'
  $status = Invoke-SqlbootInWslNoExit -Distro $Distro -WslInstallerPath $WslInstallerPath -InstallerArgs @('uninstall')
  if ($status -ne 0) {
    throw "Normal sqlboot uninstall failed with exit code $status. Purge stopped before removing Windows-side dependencies."
  }

  Clear-DockerSqlbootIntegration -Distro $Distro
  Uninstall-DockerDesktop
  Remove-CurrentUserFromDockerUsers
  Unregister-WslDistro -Distro $Distro
  Uninstall-UbuntuAppPackages
  Uninstall-WslAppPackage
  Disable-WslOptionalFeatures

  Write-Host ''
  Write-Host 'Purge complete.'
  Write-Info 'Restart Windows to finish applying WSL feature and app package removal.'
  Write-Info 'SQLBoot removes supported WSL distros, app packages, capabilities, and optional features.'
  Write-Info 'SQLBoot cannot remove the Windows-owned C:\Windows\System32\wsl.exe system stub.'
  Write-Info 'After restart, run "wsl -l -v" to confirm Windows reports no installed distributions.'
  exit 0
}

try {
  if ($CommandName -eq 'help') {
    $distroForHelp = Get-SqlbootDistro
    if (-not $distroForHelp) {
      Write-Host @'
sqlboot

Bootstrap Oracle SQL*Plus workflow with Docker Oracle XE, Instant Client, WSL2 Ubuntu, and local helper commands.

Usage:
  sqlboot init
  sqlboot start
  sqlboot status
  sqlboot logs
  sqlboot doctor
  sqlboot reset-pwd <pw>
  sqlboot stop
  sqlboot uninstall
'@
      exit 0
    }
  }

  $distro = Ensure-WslUbuntu

  if (Test-PurgeRequested) {
    $wslInstallerPath = Convert-ToWslPath -Distro $distro -WindowsPath $InstallerPath
    Run-WindowsPurge -Distro $distro -WslInstallerPath $wslInstallerPath
  }

  if ($CommandName -in @('init', 'start', 'status', 'logs', 'doctor', 'reset-pwd', 'stop', 'uninstall')) {
    Ensure-DockerDesktop
    Start-DockerDesktop
  }

  if ($CommandName -in @('init', 'start', 'status', 'logs', 'doctor', 'reset-pwd', 'stop')) {
    if (-not (Test-WslDocker $distro)) {
      if (-not (Try-EnableDockerWslIntegration -Distro $distro) -and -not (Test-WslDocker $distro)) {
        if ($script:LastWslCommandError -match 'E_ACCESSDENIED|Access is denied') {
          Restart-WslService
          throw "WSL access was denied while Docker Desktop was enabling integration. The WSL service was restarted. Close Docker Desktop popups, choose 'Restart the WSL integration' if shown, then rerun sqlboot $CommandName."
        }

        if ($script:LastWslCommandError -match 'Permission denied') {
          throw "Docker Desktop's WSL integration helper is mounted but not executable inside '$distro'. In the Docker Desktop popup, choose 'Restart the WSL integration', then rerun sqlboot $CommandName."
        }

        throw "Docker is not reachable inside WSL distro '$distro'. In Docker Desktop, enable Settings > Resources > WSL integration for this distro, then rerun sqlboot $CommandName."
      }
    }
  }

  Ensure-SqlplusRuntimeDepsInWsl -Distro $distro

  $wslInstallerPath = Convert-ToWslPath -Distro $distro -WindowsPath $InstallerPath
  Invoke-SqlbootInWsl -Distro $distro -WslInstallerPath $wslInstallerPath
} catch {
  Write-Fail $_.Exception.Message
  exit 1
}
