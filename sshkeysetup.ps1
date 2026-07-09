# Modern SSH key setup helper for Windows PowerShell.
# Copyright (C) 2026 Helal Uddin
# SPDX-License-Identifier: GPL-3.0-or-later

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Target,

    [string]$HostName,
    [string]$User,
    [int]$Port = 0,
    [string]$KeyPath = "$HOME\.ssh\id_ed25519",

    [ValidateSet("ed25519", "rsa")]
    [string]$Type = "ed25519",

    [int]$Bits = 4096,
    [string]$Comment = "${env:USERNAME}@${env:COMPUTERNAME}:$(Get-Date -Format yyyyMMdd)",

    [switch]$Force,
    [switch]$Root,
    [switch]$AcceptNewHostKey,
    [switch]$AddToAgent,
    [switch]$NoPassphrase,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "INFO: $Message"
}

function Stop-WithError {
    param([string]$Message)
    Write-Error "ERROR: $Message"
    exit 1
}

function Test-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Stop-WithError "Required command not found: $Name"
    }
}

function Invoke-CommandLine {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    if ($DryRun) {
        $quoted = @($Command) + $Arguments | ForEach-Object {
            if ($_ -match "\s") { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        }
        Write-Host ("DRY-RUN: " + ($quoted -join " "))
        return
    }

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "$Command failed with exit code $LASTEXITCODE"
    }
}

function Test-TargetPart {
    param(
        [string]$Label,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Stop-WithError "$Label is required"
    }
    if ($Value -match "\s") {
        Stop-WithError "$Label must not contain whitespace"
    }
    if ($Value -match "[\x00-\x1f\x7f]") {
        Stop-WithError "$Label contains control characters"
    }
}

function ConvertTo-ShellSingleQuoted {
    param([string]$Value)

    return "'" + ($Value -replace "'", "'\''") + "'"
}

function Invoke-SshRemoteCommand {
    param(
        [string[]]$BaseArgs,
        [string]$Target,
        [string]$RemoteCommand
    )

    & ssh @BaseArgs -- $Target $RemoteCommand
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "ssh failed with exit code $LASTEXITCODE"
    }
}

if ($Target) {
    if ($Target -notmatch "^[^@]+@[^@]+$") {
        Stop-WithError "Target must be in USER@HOST format"
    }
    if ($User -or $HostName) {
        Stop-WithError "Use either USER@HOST or -User/-HostName, not both"
    }
    $parts = $Target -split "@", 2
    $User = $parts[0]
    $HostName = $parts[1]
}

Test-TargetPart -Label "user" -Value $User
Test-TargetPart -Label "host" -Value $HostName

if ($Port -lt 0 -or $Port -gt 65535) {
    Stop-WithError "Port must be between 1 and 65535"
}
if ($Type -eq "rsa" -and $Bits -lt 3072) {
    Stop-WithError "RSA keys should be at least 3072 bits"
}

Test-Command ssh
Test-Command ssh-keygen
Test-Command scp

$KeyPath = [Environment]::ExpandEnvironmentVariables($KeyPath)
$KeyPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($KeyPath)
$KeyDir = Split-Path -Parent $KeyPath
$PublicKeyPath = "$KeyPath.pub"
$RemoteTarget = "$User@$HostName"

$SshArgs = @()
$ScpArgs = @()
if ($Port -gt 0) {
    $SshArgs += @("-p", "$Port")
    $ScpArgs += @("-P", "$Port")
}
if ($AcceptNewHostKey) {
    $SshArgs += @("-o", "StrictHostKeyChecking=accept-new")
    $ScpArgs += @("-o", "StrictHostKeyChecking=accept-new")
}

if (-not (Test-Path -LiteralPath $KeyDir)) {
    if ($DryRun) {
        Write-Host "DRY-RUN: New-Item -ItemType Directory -Force $KeyDir"
    } else {
        New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null
    }
}

if ((Test-Path -LiteralPath $KeyPath) -and $Force) {
    if ($DryRun) {
        Write-Host "DRY-RUN: Remove-Item -Force $KeyPath $PublicKeyPath"
    } else {
        Remove-Item -Force -LiteralPath $KeyPath, $PublicKeyPath -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Info "Generating $Type key at $KeyPath"
    $KeygenArgs = @("-t", $Type, "-f", $KeyPath, "-C", $Comment)
    if ($Type -eq "ed25519") {
        $KeygenArgs = @("-t", "ed25519", "-a", "100", "-f", $KeyPath, "-C", $Comment)
    } else {
        $KeygenArgs = @("-t", "rsa", "-b", "$Bits", "-f", $KeyPath, "-C", $Comment)
    }
    if ($NoPassphrase) {
        $KeygenArgs += @("-N", "")
    }
    Invoke-CommandLine -Command "ssh-keygen" -Arguments $KeygenArgs
} else {
    Write-Info "Using existing key: $KeyPath"
}

if (-not (Test-Path -LiteralPath $PublicKeyPath)) {
    Write-Info "Regenerating missing public key: $PublicKeyPath"
    if ($DryRun) {
        Write-Host "DRY-RUN: ssh-keygen -y -f `"$KeyPath`" > `"$PublicKeyPath`""
    } else {
        & ssh-keygen -y -f $KeyPath | Set-Content -NoNewline -Encoding ascii -LiteralPath $PublicKeyPath
        if ($LASTEXITCODE -ne 0) {
            Stop-WithError "ssh-keygen failed with exit code $LASTEXITCODE"
        }
    }
}

if ((Test-Path -LiteralPath $PublicKeyPath)) {
    $PublicKey = (Get-Content -Raw -LiteralPath $PublicKeyPath).Trim()
} elseif ($DryRun) {
    $PublicKey = "dry-run-public-key-placeholder"
} else {
    Stop-WithError "Public key does not exist: $PublicKeyPath"
}
if ([string]::IsNullOrWhiteSpace($PublicKey)) {
    Stop-WithError "Public key is empty: $PublicKeyPath"
}

$RemoteKeyPath = "/tmp/sshkeysetup-$([Guid]::NewGuid().ToString('N')).pub"
$QuotedRemoteKeyPath = ConvertTo-ShellSingleQuoted -Value $RemoteKeyPath
$InstallUserKey = @(
    'remote_key=' + $QuotedRemoteKeyPath,
    'remote_user=$(id -un)',
    'remote_group=$(id -gn)',
    'home_dir=$(getent passwd "$remote_user" | cut -d: -f6)',
    '[ -n "$home_dir" ] || home_dir="$HOME"',
    'umask 077',
    'if ! mkdir -p "$home_dir/.ssh" 2>/dev/null; then sudo install -d -m 700 -o "$remote_user" -g "$remote_group" "$home_dir/.ssh"; fi',
    'if ! touch "$home_dir/.ssh/authorized_keys" 2>/dev/null; then sudo touch "$home_dir/.ssh/authorized_keys"; sudo chown "$remote_user:$remote_group" "$home_dir/.ssh/authorized_keys"; fi',
    'chmod 700 "$home_dir/.ssh" 2>/dev/null || sudo chmod 700 "$home_dir/.ssh"',
    'chmod 600 "$home_dir/.ssh/authorized_keys" 2>/dev/null || sudo chmod 600 "$home_dir/.ssh/authorized_keys"',
    'chown "$remote_user:$remote_group" "$home_dir/.ssh" "$home_dir/.ssh/authorized_keys" 2>/dev/null || sudo chown "$remote_user:$remote_group" "$home_dir/.ssh" "$home_dir/.ssh/authorized_keys"',
    'if ! grep -qxF -f "$remote_key" "$home_dir/.ssh/authorized_keys" 2>/dev/null; then if ! cat "$remote_key" >> "$home_dir/.ssh/authorized_keys" 2>/dev/null; then sudo sh -c ''cat "$1" >> "$2"'' sh "$remote_key" "$home_dir/.ssh/authorized_keys"; fi; fi'
) -join '; '

Write-Info "Installing public key for $RemoteTarget"
if ($DryRun) {
    Write-Host "DRY-RUN: scp $PublicKeyPath to ${RemoteTarget}:$RemoteKeyPath"
    Write-Host "DRY-RUN: install $RemoteKeyPath into $RemoteTarget authorized_keys"
} else {
    & scp @ScpArgs "$PublicKeyPath" "${RemoteTarget}:$RemoteKeyPath"
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "scp failed with exit code $LASTEXITCODE"
    }
    Invoke-SshRemoteCommand -BaseArgs $SshArgs -Target $RemoteTarget -RemoteCommand $InstallUserKey
}

if ($Root -and $User -ne "root") {
    $InstallRootKey = @(
        'remote_key=' + $QuotedRemoteKeyPath,
        'sudo install -d -m 700 -o root -g root /root/.ssh',
        'sudo touch /root/.ssh/authorized_keys',
        'sudo chown root:root /root/.ssh/authorized_keys',
        'sudo chmod 600 /root/.ssh/authorized_keys',
        'sudo grep -qxF -f "$remote_key" /root/.ssh/authorized_keys || sudo sh -c ''cat "$1" >> /root/.ssh/authorized_keys'' sh "$remote_key"'
    ) -join '; '
    Write-Info "Installing public key for root@$HostName through sudo on $RemoteTarget"
    if ($DryRun) {
        Write-Host "DRY-RUN: install $PublicKeyPath into root@$HostName authorized_keys through sudo on $RemoteTarget"
    } else {
        Invoke-SshRemoteCommand -BaseArgs $SshArgs -Target $RemoteTarget -RemoteCommand $InstallRootKey
    }
}

if (-not $DryRun) {
    $CleanupRemoteKey = "rm -f $QuotedRemoteKeyPath"
    & ssh @SshArgs -- $RemoteTarget $CleanupRemoteKey
}

if ($AddToAgent) {
    Test-Command ssh-add
    Invoke-CommandLine -Command "ssh-add" -Arguments @($KeyPath)
}

Write-Info "Verifying key login for $RemoteTarget"
$VerifyArgs = @() + $SshArgs + @("-o", "BatchMode=yes", "-i", $KeyPath, $RemoteTarget, 'printf "SSH key login OK\n"')
Invoke-CommandLine -Command "ssh" -Arguments $VerifyArgs

Write-Info "Done. Keep password login enabled until you have verified key login from a separate terminal."
