<#
  Get-ComputerSpecs.ps1
  Collects the computer's specs (model, CPU, RAM type and speed, storage as
  NVMe / SATA SSD / HDD, motherboard with BIOS version, OS and GPU) and saves
  an English text block, ready for a sale listing, to Desktop\Computer-specs-en.txt.

  No installs needed. How to run:
    - Right-click the file > "Run with PowerShell"
    - or:  powershell -ExecutionPolicy Bypass -File Get-ComputerSpecs.ps1
  Tip: running as administrator makes some fields more complete.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Try-Get([scriptblock]$sb, $default = 'Nao disponivel') {
    try { $r = & $sb; if ($null -eq $r -or "$r".Trim() -eq '') { $default } else { $r } } catch { $default }
}

# ---------- Processador ----------
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuTxt = Try-Get { "{0} ({1} nucleos / {2} threads, {3:N2} GHz)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, ($cpu.MaxClockSpeed / 1000) }

# ---------- Memoria RAM ----------
$mods = @(Get-CimInstance Win32_PhysicalMemory)
$totalGB = [math]::Round((($mods | Measure-Object Capacity -Sum).Sum) / 1GB)
$typeMap = @{ '20'='DDR'; '21'='DDR2'; '24'='DDR3'; '26'='DDR4'; '34'='DDR5'; '35'='LPDDR5' }
$t = $mods | Select-Object -First 1
$ramType = if ($typeMap.ContainsKey("$($t.SMBIOSMemoryType)")) { $typeMap["$($t.SMBIOSMemoryType)"] } else { 'Tipo nao identificado' }
$speed = if ($t.ConfiguredClockSpeed) { $t.ConfiguredClockSpeed } else { $t.Speed }
$sizes = ($mods | ForEach-Object { "{0} GB" -f [math]::Round($_.Capacity / 1GB) }) -join ' + '
$slots = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
$slotTxt = if ($slots) { " - {0} de {1} slots ocupados" -f $mods.Count, $slots } else { '' }
$ramTxt = "{0} GB {1} {2} MHz ({3}){4}" -f $totalGB, $ramType, $speed, $sizes, $slotTxt

# ---------- Armazenamento ----------
$diskLines = @()
$pdisks = @(Get-PhysicalDisk)
if ($pdisks.Count -gt 0) {
    foreach ($d in $pdisks) {
        $bus = "$($d.BusType)"; $media = "$($d.MediaType)"
        if ($bus -eq 'NVMe') { $kind = 'SSD NVMe' }
        elseif ($media -eq 'SSD') { $kind = "SSD $bus" }
        elseif ($media -eq 'HDD') { $kind = "HD $bus" }
        elseif ($bus -eq 'USB') { $kind = 'Disco USB' }
        else { $kind = "Disco $bus" }
        $diskLines += "  - {0,-10} {1} {2} GB" -f $kind, $d.FriendlyName.Trim(), [math]::Round($d.Size / 1GB)
    }
} else {
    foreach ($d in Get-CimInstance Win32_DiskDrive) {
        $diskLines += "  - {0} {1} GB ({2})" -f $d.Model, [math]::Round($d.Size / 1GB), $d.InterfaceType
    }
}

# ---------- Placa-mae ----------
$bios = Get-CimInstance Win32_BIOS
$cs = Get-CimInstance Win32_ComputerSystem
$bad = '^(|To be filled by O\.E\.M\.|Default string|System Product Name|Not Applicable|None|Base Board.*)$'
$mbMan = ''; $mbProd = ''
# 1) Win32_BaseBoard
$bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bb) { $mbMan = "$($bb.Manufacturer)".Trim(); $mbProd = "$($bb.Product)".Trim() }
# 2) Win32_ComputerSystemProduct (modelo)
if ($mbProd -match $bad) {
    $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($csp) {
        if ($mbMan -match $bad) { $mbMan = "$($csp.Vendor)".Trim() }
        $mbProd = "$($csp.Name)".Trim()
    }
}
# 3) Registro
if ($mbProd -match $bad -or $mbMan -match $bad) {
    $reg = Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -ErrorAction SilentlyContinue
    if ($reg) {
        if ($mbMan -match $bad) { $mbMan = "$($reg.BaseBoardManufacturer)".Trim() }
        if ($mbProd -match $bad) { $mbProd = "$($reg.BaseBoardProduct)".Trim() }
    }
}
$mbName = ("$mbMan $mbProd").Trim()
if ($mbName -eq '') { $mbName = 'Nao identificada - conferir na placa' }
$mbTxt = "{0} (BIOS {1})" -f $mbName, $bios.SMBIOSBIOSVersion
$modelTxt = "{0} {1}" -f $cs.Manufacturer, $cs.Model

# ---------- Sistema operacional ----------
$os = Get-CimInstance Win32_OperatingSystem
$disp = Try-Get { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion } ''
$act = Try-Get {
    $l = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" | Select-Object -First 1
    if ($l.LicenseStatus -eq 1) { 'Ativado' } else { 'Nao ativado' }
} 'Ativacao nao verificada'
$osTxt = "{0} {1} (build {2}) {3} - {4}" -f $os.Caption, $disp, $os.BuildNumber, $os.OSArchitecture, $act

# ---------- Placa de video ----------
$gpuLines = @()
$vidKeys = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue
foreach ($g in Get-CimInstance Win32_VideoController) {
    $vram = $null
    foreach ($k in $vidKeys) {
        $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
        if ($p.DriverDesc -eq $g.Name -and $p.'HardwareInformation.qwMemorySize') { $vram = [math]::Round($p.'HardwareInformation.qwMemorySize' / 1GB, 1) }
    }
    if (-not $vram -and $g.AdapterRAM -gt 0) { $vram = [math]::Round($g.AdapterRAM / 1GB, 1) }
    $vramTxt = if ($vram) { " $vram GB" } else { '' }
    $gpuLines += "  - {0}{1}" -f $g.Name, $vramTxt
}

# ---------- Monta os textos (mesmos valores, rotulos PT e EN) ----------
$nl = [Environment]::NewLine
$disks = $diskLines -join $nl
$gpus  = $gpuLines -join $nl
$data  = Get-Date -Format 'dd/MM/yyyy HH:mm'



# ---------- Traducao dos valores para o arquivo em ingles ----------
function ConvertTo-EnglishValue([string]$t) {
    $map = [ordered]@{
        'Nao identificada - conferir na placa' = 'Not identified - check the board'
        'Ativacao nao verificada'              = 'Activation not checked'
        'Tipo nao identificado'                = 'Unknown type'
        'Nao disponivel'                       = 'Not available'
        'Nao ativado'                          = 'Not activated'
        'Ativado'                              = 'Activated'
        'slots ocupados'                       = 'slots used'
        'nucleos'                              = 'cores'
        'Disco USB'                            = 'USB drive'
        'Disco '                               = 'Disk '
        '64 bits'                              = '64-bit'
        '32 bits'                              = '32-bit'
    }
    foreach ($k in $map.Keys) { $t = $t -replace [regex]::Escape($k), $map[$k] }
    $t = $t -replace '(\d+) de (\d+) slots', '$1 of $2 slots'
    $t = $t -replace '(?m)^(\s*-\s*)HD ', '$1HDD '
    return $t
}
$modelEN = ConvertTo-EnglishValue $modelTxt
$cpuEN   = ConvertTo-EnglishValue $cpuTxt
$ramEN   = ConvertTo-EnglishValue $ramTxt
$disksEN = ConvertTo-EnglishValue $disks
$mbEN    = ConvertTo-EnglishValue $mbTxt
$osEN    = ConvertTo-EnglishValue $osTxt
$gpusEN  = ConvertTo-EnglishValue $gpus

$outEN = @"
==== COMPUTER SPECS ====
Model          : $modelEN
CPU            : $cpuEN
RAM            : $ramEN
Storage        :
$disksEN
Motherboard    : $mbEN
OS             : $osEN
GPU            :
$gpusEN
Generated on   : $data
========================
"@

# The Desktop may be inside OneDrive; the exact path is printed at the end.
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Path $desktop)) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }
$enc = New-Object System.Text.UTF8Encoding $true
$fileEN = Join-Path $desktop 'Computer-specs-en.txt'
if (Test-Path $fileEN) { Remove-Item $fileEN -Force }   # overwrite any older version
[System.IO.File]::WriteAllText($fileEN, $outEN, $enc)
try { $outEN | Set-Clipboard } catch {}

Write-Host $outEN

# Check that the motherboard line was written as shown on screen
if ([System.IO.File]::ReadAllText($fileEN) -notmatch [regex]::Escape($mbEN)) {
    Write-Host "WARNING: the motherboard line was not written as expected." -ForegroundColor Yellow
}

Write-Host "`nSaved to: $fileEN (text also copied to the clipboard)" -ForegroundColor Green
if ($Host.Name -eq 'ConsoleHost') { Read-Host 'Press Enter to close' | Out-Null }
