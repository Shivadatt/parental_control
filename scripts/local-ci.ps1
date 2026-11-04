<#
.SYNOPSIS
    Local CI Test Suite Runner for Android-first Parental Control Application.
.DESCRIPTION
    Orchestrates the complete 5-stage local verification pipeline without hosted dependencies:
      Stage 1: Dart Static Analysis (dart analyze)
      Stage 2: Flutter Unit & Widget Tests (flutter test - 408 tests)
      Stage 3: Deno Edge Function Unit Tests (deno test - 150 tests)
      Stage 4: Android/Kotlin Unit Tests (gradle testDebugUnitTest - 39 tests)
      Stage 5: Disposable PostgreSQL 16 33-file SQL regression chain
.PARAMETER SkipSql
    Skips the PostgreSQL disposable chain stage.
.PARAMETER SkipGradle
    Skips the Gradle Android unit tests.
.PARAMETER SkipFlutter
    Skips Flutter analyzer and widget tests.
.PARAMETER SkipDeno
    Skips Deno edge function tests.
.PARAMETER ContinueOnError
    Runs all stages even if an earlier stage fails.
.PARAMETER PgPort
    PostgreSQL port for the disposable cluster (default: 55581 or $env:PGPORT).
.PARAMETER PgBin
    Directory containing PostgreSQL client binaries (psql, createdb, dropdb).
.PARAMETER LogDir
    Directory to store execution logs (default: .tools/ci-logs).
#>
[CmdletBinding()]
param(
    [switch]$SkipSql,
    [switch]$SkipGradle,
    [switch]$SkipFlutter,
    [switch]$SkipDeno,
    [switch]$ContinueOnError,
    [int]$PgPort = 0,
    [string]$PgBin = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $RepoRoot ".tools\ci-logs"
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$SummaryLog = Join-Path $LogDir "ci-run-$Timestamp.log"
$ExitCodes = @{}
$Durations = @{}
$Stages = @()

function Log-Message([string]$Msg) {
    $formatted = "[$(Get-Date -Format 'HH:mm:ss')] $Msg"
    Write-Host $formatted
    Add-Content -Path $SummaryLog -Value $formatted
}

function Resolve-Tool([string]$PreferredPath, [string]$CommandName) {
    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        try {
            if (Test-Path -LiteralPath $PreferredPath -ErrorAction SilentlyContinue) {
                $resolved = Resolve-Path -LiteralPath $PreferredPath -ErrorAction SilentlyContinue
                if ($resolved) { return $resolved.Path }
            }
        } catch {
            # Inaccessible symlink or permission issue, fallback to Get-Command
        }
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Invoke-NativeCommand([scriptblock]$CommandBlock, [string]$OutputFile) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $CommandBlock > $OutputFile 2>&1
        return $LASTEXITCODE
    } catch {
        Add-Content -Path $OutputFile -Value $_.Exception.Message
        return 1
    } finally {
        $ErrorActionPreference = $prev
    }
}

Log-Message "================================================================"
Log-Message "Starting Local CI Pipeline (CI-01)"
Log-Message "Repository Root: $RepoRoot"
Log-Message "Log Directory  : $LogDir"
Log-Message "================================================================"

# -----------------------------------------------------------------------------
# Tool Discovery
# -----------------------------------------------------------------------------
$DartBin = Resolve-Tool (Join-Path $RepoRoot ".fvm\flutter_sdk\bin\dart.bat") "dart"
$FlutterBin = Resolve-Tool (Join-Path $RepoRoot ".fvm\flutter_sdk\bin\flutter.bat") "flutter"
$DenoBin = Resolve-Tool "C:\Users\ASUS\AppData\Local\Microsoft\WinGet\Links\deno.exe" "deno"
$Gradlew = Join-Path $RepoRoot "android\gradlew.bat"

if ([string]::IsNullOrWhiteSpace($env:DENO_DIR)) {
    $env:DENO_DIR = "C:\Users\ASUS\AppData\Local\deno"
}

if ([string]::IsNullOrWhiteSpace($PgBin)) {
    $PgBinCandidates = @(
        (Join-Path $RepoRoot ".tools\pgsql16\pgsql\bin"),
        "C:\Program Files\PostgreSQL\16\bin"
    )
    foreach ($cand in $PgBinCandidates) {
        if (Test-Path (Join-Path $cand "psql.exe") -ErrorAction SilentlyContinue) {
            $PgBin = $cand
            break
        }
    }
}

if ($PgPort -eq 0) {
    if (-not [string]::IsNullOrWhiteSpace($env:PGPORT)) {
        $PgPort = [int]$env:PGPORT
    } else {
        $PgPort = 55581
    }
}

# -----------------------------------------------------------------------------
# Stage 1: Dart Analyze
# -----------------------------------------------------------------------------
if (-not $SkipFlutter) {
    $stage = "Stage 1: Dart Analyze"
    $Stages += $stage
    $stageLog = Join-Path $LogDir "stage1-dart-analyze-$Timestamp.log"
    Log-Message "Starting $stage..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    if (-not $DartBin) {
        Log-Message "ERROR: Dart executable not found."
        $ExitCodes[$stage] = 127
        $Durations[$stage] = 0
        if (-not $ContinueOnError) { exit 127 }
    } else {
        $code = Invoke-NativeCommand { & $DartBin analyze } $stageLog
        $sw.Stop()
        $ExitCodes[$stage] = $code
        $Durations[$stage] = $sw.Elapsed.TotalSeconds
        if ($code -eq 0) {
            Log-Message "$stage PASSED ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)"
        } else {
            Log-Message "$stage FAILED with code $code. See $stageLog"
            if (-not $ContinueOnError) { exit 1 }
        }
    }
}

# -----------------------------------------------------------------------------
# Stage 2: Flutter Test
# -----------------------------------------------------------------------------
if (-not $SkipFlutter) {
    $stage = "Stage 2: Flutter Unit & Widget Tests"
    $Stages += $stage
    $stageLog = Join-Path $LogDir "stage2-flutter-test-$Timestamp.log"
    Log-Message "Starting $stage..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    if (-not $FlutterBin) {
        Log-Message "ERROR: Flutter executable not found."
        $ExitCodes[$stage] = 127
        $Durations[$stage] = 0
        if (-not $ContinueOnError) { exit 127 }
    } else {
        $code = Invoke-NativeCommand { & $FlutterBin test } $stageLog
        $sw.Stop()
        $ExitCodes[$stage] = $code
        $Durations[$stage] = $sw.Elapsed.TotalSeconds
        if ($code -eq 0) {
            Log-Message "$stage PASSED ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)"
        } else {
            Log-Message "$stage FAILED with code $code. See $stageLog"
            if (-not $ContinueOnError) { exit 2 }
        }
    }
}

# -----------------------------------------------------------------------------
# Stage 3: Deno Edge Function Tests
# -----------------------------------------------------------------------------
if (-not $SkipDeno) {
    $stage = "Stage 3: Deno Edge Function Tests"
    $Stages += $stage
    $stageLog = Join-Path $LogDir "stage3-deno-test-$Timestamp.log"
    Log-Message "Starting $stage..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    if (-not $DenoBin) {
        Log-Message "ERROR: Deno executable not found."
        $ExitCodes[$stage] = 127
        $Durations[$stage] = 0
        if (-not $ContinueOnError) { exit 127 }
    } else {
        $code = Invoke-NativeCommand { & $DenoBin test --allow-read supabase/functions/ } $stageLog
        $sw.Stop()
        $ExitCodes[$stage] = $code
        $Durations[$stage] = $sw.Elapsed.TotalSeconds
        if ($code -eq 0) {
            Log-Message "$stage PASSED ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)"
        } else {
            Log-Message "$stage FAILED with code $code. See $stageLog"
            if (-not $ContinueOnError) { exit 3 }
        }
    }
}

# -----------------------------------------------------------------------------
# Stage 4: Gradle Android Unit Tests
# -----------------------------------------------------------------------------
if (-not $SkipGradle) {
    $stage = "Stage 4: Gradle Android Unit Tests"
    $Stages += $stage
    $stageLog = Join-Path $LogDir "stage4-gradle-test-$Timestamp.log"
    Log-Message "Starting $stage..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    if (-not (Test-Path $Gradlew -ErrorAction SilentlyContinue)) {
        Log-Message "ERROR: gradlew.bat not found at $Gradlew"
        $ExitCodes[$stage] = 127
        $Durations[$stage] = 0
        if (-not $ContinueOnError) { exit 127 }
    } else {
        Push-Location (Join-Path $RepoRoot "android")
        try {
            $code = Invoke-NativeCommand { & .\gradlew.bat :app:testDebugUnitTest --configure-on-demand } $stageLog
        } finally {
            Pop-Location
        }
        $sw.Stop()
        $ExitCodes[$stage] = $code
        $Durations[$stage] = $sw.Elapsed.TotalSeconds
        if ($code -eq 0) {
            Log-Message "$stage PASSED ($([math]::Round($sw.Elapsed.TotalSeconds, 1))s)"
        } else {
            Log-Message "$stage FAILED with code $code. See $stageLog"
            if (-not $ContinueOnError) { exit 4 }
        }
    }
}

# -----------------------------------------------------------------------------
# Stage 5: Disposable PostgreSQL 33-File SQL Regression Chain
# -----------------------------------------------------------------------------
if (-not $SkipSql) {
    $stage = "Stage 5: Disposable PostgreSQL 33-File SQL Chain"
    $Stages += $stage
    $stageLog = Join-Path $LogDir "stage5-sql-chain-$Timestamp.log"
    Log-Message "Starting $stage on port $PgPort..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $Psql = Join-Path $PgBin "psql.exe"
    $Createdb = Join-Path $PgBin "createdb.exe"
    $Dropdb = Join-Path $PgBin "dropdb.exe"
    
    if (-not (Test-Path $Psql -ErrorAction SilentlyContinue) -or -not (Test-Path $Createdb -ErrorAction SilentlyContinue) -or -not (Test-Path $Dropdb -ErrorAction SilentlyContinue)) {
        Log-Message "ERROR: PostgreSQL binaries not found in $PgBin"
        $ExitCodes[$stage] = 127
        $Durations[$stage] = 0
        if (-not $ContinueOnError) { exit 127 }
    } else {
        $DbName = "ci_disposable_$Timestamp"
        
        $SqlChainFiles = @(
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
            "supabase/tests/75_signaling_replay_index_duplicate_guard.sql",
            "supabase/tests/76_zone_delete_atomic_rpc.sql",
            "supabase/tests/45_device_recovery.sql"
        )
        
        try {
            & $Dropdb -h 127.0.0.1 -p $PgPort -U postgres --if-exists $DbName 2>$null
            & $Createdb -h 127.0.0.1 -p $PgPort -U postgres $DbName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create disposable database $DbName (cluster running on port $PgPort?)"
            }
            
            $PsqlArgs = @(
                "-h", "127.0.0.1",
                "-p", "$PgPort",
                "-U", "postgres",
                "-v", "ON_ERROR_STOP=1"
            )
            foreach ($f in $SqlChainFiles) {
                $PsqlArgs += "-f"
                $PsqlArgs += (Join-Path $RepoRoot $f)
            }
            $PsqlArgs += "-d"
            $PsqlArgs += $DbName
            
            $code = Invoke-NativeCommand { & $Psql @PsqlArgs } $stageLog
            $ExitCodes[$stage] = $code
            
            # Count assertions and errors
            $logContent = Get-Content -Path $stageLog -Raw -ErrorAction SilentlyContinue
            $assertFails = ([regex]::Matches($logContent, "ASSERTION FAILED")).Count
            $errors = ([regex]::Matches($logContent, "ERROR:")).Count
            
            Add-Content -Path $stageLog -Value "`n--- CI SUMMARY: PSQL_EXIT=$code ASSERT_FAILED=$assertFails ERRORS=$errors FILES=$($SqlChainFiles.Count) ---"
            
            if ($code -eq 0 -and $assertFails -eq 0 -and $errors -eq 0) {
                Log-Message "$stage PASSED ($($SqlChainFiles.Count) files, $([math]::Round($sw.Elapsed.TotalSeconds, 1))s)"
            } else {
                Log-Message "$stage FAILED (code=$code, assert_failed=$assertFails, errors=$errors). See $stageLog"
                if (-not $ContinueOnError) { exit 5 }
            }
        } catch {
            $code = 5
            $ExitCodes[$stage] = $code
            Log-Message "$stage FAILED: $_. See $stageLog"
            if (-not $ContinueOnError) { exit 5 }
        } finally {
            & $Dropdb -h 127.0.0.1 -p $PgPort -U postgres --if-exists $DbName 2>$null
            $sw.Stop()
            $Durations[$stage] = $sw.Elapsed.TotalSeconds
        }
    }
}

# -----------------------------------------------------------------------------
# Summary Report
# -----------------------------------------------------------------------------
Log-Message "================================================================"
Log-Message "Local CI Pipeline Summary"
Log-Message "================================================================"
$OverallSuccess = $true
$FirstFailureCode = 0
foreach ($s in $Stages) {
    $code = $ExitCodes[$s]
    $dur = [math]::Round($Durations[$s], 1)
    $status = if ($code -eq 0) { "PASSED" } else { "FAILED ($code)" }
    if ($code -ne 0) {
        $OverallSuccess = $false
        if ($FirstFailureCode -eq 0) { $FirstFailureCode = $code }
    }
    Log-Message (("{0,-45} : {1,-12} [{2,5}s]" -f $s, $status, $dur))
}
Log-Message "================================================================"

if ($OverallSuccess) {
    Log-Message "ALL STAGES PASSED. Local working tree verified clean."
    exit 0
} else {
    Log-Message "PIPELINE FAILED. One or more stages failed."
    if ($FirstFailureCode -ne 0) { exit $FirstFailureCode }
    exit 1
}
