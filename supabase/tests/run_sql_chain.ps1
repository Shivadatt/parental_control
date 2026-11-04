<#
.SYNOPSIS
    CHAIN-01: Documented 33-File PostgreSQL Regression Test Chain Runner (PowerShell).

.DESCRIPTION
    Executes the documented 33-file SQL test chain from supabase/tests/README.md
    against a local disposable PostgreSQL database.

.PARAMETER DatabaseName
    Optional custom disposable database name. Must match disposable prefix whitelist.
    Default: p6chain_<timestamp> or p6chain_neg_<timestamp>.

.PARAMETER LogPath
    Path to write the full psql log. Default: .tools/chain_<dbname>.log.

.PARAMETER Port
    PostgreSQL cluster port. Default: 55581.

.PARAMETER HostName
    PostgreSQL cluster host. Default: 127.0.0.1.

.PARAMETER User
    PostgreSQL superuser/admin. Default: postgres.

.PARAMETER DataDir
    Path to disposable cluster data directory if cluster must be started. Default: .tools/pgdata_chain.

.PARAMETER NegativeControl
    Switch to run the SQL-05 negative control (injects lossy RPC immediately before test 76).
    Expected result is exit code 3 with 1 assertion failure in test 76.

.PARAMETER KeepDatabase
    Switch to prevent dropping the disposable database on completion.

.PARAMETER StopCluster
    Switch to stop the PostgreSQL cluster on exit if it was started by this script.

.EXAMPLE
    .\supabase\tests\run_sql_chain.ps1
    .\supabase\tests\run_sql_chain.ps1 -NegativeControl
    .\supabase\tests\run_sql_chain.ps1 -Port 55581 -KeepDatabase
#>

[CmdletBinding()]
param(
    [string]$DatabaseName = "",
    [string]$LogPath = "",
    [int]$Port = 55581,
    [string]$HostName = "127.0.0.1",
    [string]$User = "postgres",
    [string]$DataDir = ".tools/pgdata_chain",
    [switch]$NegativeControl,
    [switch]$KeepDatabase,
    [switch]$StopCluster
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -Path $PSScriptRoot\..\..).FullName
Set-Location -Path $repoRoot

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
    if ($NegativeControl) {
        $DatabaseName = "p6chain_neg_$timestamp"
    } else {
        $DatabaseName = "p6chain_$timestamp"
    }
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $toolsDir = Join-Path $repoRoot ".tools"
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }
    $LogPath = Join-Path $toolsDir "chain_$DatabaseName.log"
}

# Resolve binaries
$pgBin = Join-Path $repoRoot ".tools\pgsql16\pgsql\bin"
$psql = Join-Path $pgBin "psql.exe"
$createdb = Join-Path $pgBin "createdb.exe"
$dropdb = Join-Path $pgBin "dropdb.exe"
$pgIsReady = Join-Path $pgBin "pg_isready.exe"
$pgCtl = Join-Path $pgBin "pg_ctl.exe"
$initdb = Join-Path $pgBin "initdb.exe"

foreach ($tool in @($psql, $createdb, $dropdb, $pgIsReady)) {
    if (-not (Test-Path $tool)) {
        throw "Required PostgreSQL binary not found: $tool"
    }
}

# Safety Check: Whitelist disposable database prefix
$disposableRegex = "^(p6chain_|p5rpc_|ci_|test_|disposable_|parentcontrol_race_)"
if ($DatabaseName -notmatch $disposableRegex) {
    throw "Database name '$DatabaseName' violates disposable naming policy! Must match $disposableRegex"
}

$startedCluster = $false
$absDataDir = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $DataDir))

function Cleanup-Environment {
    param()
    if (-not $KeepDatabase -and -not [string]::IsNullOrWhiteSpace($DatabaseName)) {
        & $pgIsReady -h $HostName -p $Port -U $User | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Dropping disposable database $DatabaseName..."
            & $dropdb -h $HostName -p $Port -U $User --if-exists $DatabaseName | Out-Null
        }
    }
    if ($startedCluster -and $StopCluster) {
        Write-Host "Stopping disposable PostgreSQL cluster at $absDataDir..."
        & $pgCtl -D $absDataDir stop -m fast | Out-Null
    }
}

try {
    # 1. Check or start cluster
    $isReadyArgs = @("-h", $HostName, "-p", $Port, "-U", $User)
    & $pgIsReady $isReadyArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No active PostgreSQL cluster on ${HostName}:${Port}."
        Write-Host "Initializing/Starting disposable cluster at $absDataDir..."
        
        if (-not (Test-Path $absDataDir)) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $absDataDir) -Force -ErrorAction SilentlyContinue | Out-Null
            & $initdb -U $User -A trust -E UTF8 --locale=C -D $absDataDir | Out-Null
        }

        # Handle dead stale postmaster.pid
        $pidFile = Join-Path $absDataDir "postmaster.pid"
        if (Test-Path $pidFile) {
            $pidCandidate = (Get-Content $pidFile -TotalCount 1).Trim()
            $proc = Get-Process -Id $pidCandidate -ErrorAction SilentlyContinue
            if ($null -eq $proc) {
                Write-Host "Removing stale postmaster.pid (PID $pidCandidate is dead)..."
                Remove-Item -Force $pidFile
            }
        }

        $serverLog = Join-Path $absDataDir "server.log"
        & $pgCtl -D $absDataDir -l $serverLog -o "-p $Port -c listen_addresses=$HostName" start
        $startedCluster = $true

        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            & $pgIsReady $isReadyArgs | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }

        if (-not $ready) {
            throw "Failed to start disposable cluster on port $Port within 15 seconds."
        }
        Write-Host "Disposable cluster ready on ${HostName}:${Port}."
    } else {
        Write-Host "Connected to active PostgreSQL cluster on ${HostName}:${Port}."
    }

    # 2. Setup isolated fresh database
    & $dropdb -h $HostName -p $Port -U $User --if-exists $DatabaseName | Out-Null
    & $createdb -h $HostName -p $Port -U $User $DatabaseName
    Write-Host "Created fresh disposable database: $DatabaseName"

    # 3. Assemble 33-file chain
    $files = @(
        "supabase/tests/00_auth_stub.sql",
        "supabase/tests/05_realtime_stub.sql",
        "supabase/migrations/20260101000000_core.sql",
        "supabase/migrations/20260101000100_functions.sql",
        "supabase/migrations/20260101000200_rls.sql",
        "supabase/migrations/20260101000300_service_role_grants.sql",
        "supabase/migrations/20260101000400_device_recovery.sql",
        "supabase/migrations/20260101000500_child_contact_ids.sql",
        "supabase/migrations/20260101000600_atomic_pairing_invite.sql",
        "supabase/migrations/20261028000100_remote_session_concurrency.sql",
        "supabase/migrations/20261028000200_parent_controlled_session_lifetime.sql",
        "supabase/migrations/20261028000300_signaling_open_session.sql",
        "supabase/migrations/20261030000100_abandoned_session_sweep.sql",
        "supabase/migrations/20261030000200_phase1_authorization.sql",
        "supabase/migrations/20261030000300_retention_sweep.sql",
        "supabase/migrations/20261103000100_zone_delete_atomic_rpc.sql",
        "supabase/tests/10_schema.sql",
        "supabase/tests/20_fixtures.sql",
        "supabase/tests/50_realtime_policy.sql",
        "supabase/tests/30_rls.sql",
        "supabase/tests/40_functions.sql",
        "supabase/tests/55_pairing_invite_atomic.sql",
        "supabase/tests/60_remote_session_concurrency.sql",
        "supabase/tests/61_parent_controlled_lifetime.sql",
        "supabase/tests/62_signaling_consented_session.sql",
        "supabase/tests/63_abandoned_session_sweep.sql",
        "supabase/tests/70_phase1_authorization.sql",
        "supabase/tests/71_phase1_rollback_privileges.sql",
        "supabase/tests/72_retention_sweep.sql",
        "supabase/tests/74_sweep_indexes_and_repeatability.sql",
        "supabase/tests/75_signaling_replay_index_duplicate_guard.sql"
    )

    if ($NegativeControl) {
        $negFile = "supabase/tests/fixtures/sql05_lossy_negative.sql"
        if (-not (Test-Path $negFile)) {
            $negFile = ".tools/p5coord_rpc_lossy_negative.sql"
        }
        if (-not (Test-Path $negFile)) {
            throw "Negative control fixture not found at $negFile"
        }
        $files += $negFile
    }

    $files += "supabase/tests/76_zone_delete_atomic_rpc.sql"
    $files += "supabase/tests/45_device_recovery.sql"

    $argsList = @(
        "-h", $HostName,
        "-p", $Port,
        "-U", $User,
        "-v", "ON_ERROR_STOP=1"
    )
    foreach ($f in $files) {
        $argsList += "-f"
        $argsList += $f
    }
    $argsList += "-d"
    $argsList += $DatabaseName

    Write-Host "Executing SQL chain ($($files.Count) files) into $DatabaseName..."
    Write-Host "Log file: $LogPath"

    $errLog = "$LogPath.err"
    if (Test-Path $errLog) { Remove-Item -Force $errLog }
    if (Test-Path $LogPath) { Remove-Item -Force $LogPath }

    $process = Start-Process -FilePath $psql -ArgumentList $argsList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $LogPath -RedirectStandardError $errLog
    $psqlExit = $process.ExitCode

    if (Test-Path $errLog) {
        $errContent = Get-Content -Path $errLog -Raw
        if (-not [string]::IsNullOrWhiteSpace($errContent)) {
            Add-Content -Path $LogPath -Value $errContent
        }
        Remove-Item -Force $errLog -ErrorAction SilentlyContinue
    }

    # 4. Analyze results
    $totalLines = (Get-Content -Path $LogPath | Measure-Object -Line).Lines
    $assertFails = (Select-String -Path $LogPath -Pattern "ASSERTION FAILED").Count
    $errorCount = (Select-String -Path $LogPath -Pattern "ERROR:").Count

    $modeStr = if ($NegativeControl) { "NEGATIVE_CONTROL (SQL-05 lossy RPC)" } else { "NORMAL (all assertions must pass)" }

    Write-Host ""
    Write-Host "=================================================================="
    Write-Host "                    CHAIN-01 EXECUTION SUMMARY                    "
    Write-Host "=================================================================="
    Write-Host "Database       : $DatabaseName"
    Write-Host "Target Cluster : ${HostName}:${Port}"
    Write-Host "Mode           : $modeStr"
    Write-Host "Files Executed : $($files.Count)"
    Write-Host "psql Exit Code : $psqlExit"
    Write-Host "Log Line Count : $totalLines"
    Write-Host "Assert Failed  : $assertFails"
    Write-Host "Errors Count   : $errorCount"
    Write-Host "Log Output     : $LogPath"
    Write-Host "------------------------------------------------------------------"

    if ($NegativeControl) {
        if ($psqlExit -eq 3 -and $assertFails -ge 1) {
            Write-Host "STATUS         : EXPECTED NEGATIVE PASS (Test 76 caught the lossy RPC)"
            Write-Host "=================================================================="
            return 0
        } else {
            Write-Host "STATUS         : UNEXPECTED RESULT (Negative control did not fail as expected)"
            Write-Host "=================================================================="
            return 1
        }
    } else {
        if ($psqlExit -eq 0 -and $assertFails -eq 0 -and $errorCount -eq 0) {
            Write-Host "STATUS         : PASSED (All 33 test/migration files clean)"
            Write-Host "=================================================================="
            return 0
        } else {
            Write-Host "STATUS         : FAILED (Errors or assertion failures detected)"
            Write-Host "=================================================================="
            return $psqlExit
        }
    }
} finally {
    Cleanup-Environment
}
