# SystemInfo.psm1
# Modulo de solo lectura que reune informacion basica del equipo:
# nombre, sistema operativo, CPU, RAM, discos y tiempo de actividad.
# Usa Get-ITSafeValue del modulo Common.psm1.

function Get-ITSystemInfo {
    <#
        Devuelve un objeto con los datos principales del sistema.
        Cada dato se obtiene por separado para que el fallo de uno solo
        (por ejemplo, no poder leer la CPU) no impida ver los demas.
    #>

    $hostname = Get-ITSafeValue { $env:COMPUTERNAME }

    $osCaption = Get-ITSafeValue { (Get-CimInstance -ClassName Win32_OperatingSystem).Caption }
    $osVersion = Get-ITSafeValue { (Get-CimInstance -ClassName Win32_OperatingSystem).Version }
    $osBuild = Get-ITSafeValue { (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber }

    $cpuName = Get-ITSafeValue {
        (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Name
    }

    $ramTotalGB = 'No disponible'
    $ramUsedGB = 'No disponible'
    $ramUsedPercent = 'No disponible'
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalKB = $os.TotalVisibleMemorySize
        $freeKB = $os.FreePhysicalMemory
        $ramTotalGB = [math]::Round($totalKB / 1MB, 2)
        $ramUsedGB = [math]::Round(($totalKB - $freeKB) / 1MB, 2)
        $ramUsedPercent = [math]::Round((($totalKB - $freeKB) / $totalKB) * 100, 1)
    }
    catch { }

    $disks = @()
    try {
        $logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3'
        foreach ($disk in $logicalDisks) {
            try {
                $sizeGB = [math]::Round($disk.Size / 1GB, 2)
                $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                $freePercent = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1) } else { 0 }

                $disks += [PSCustomObject]@{
                    DriveLetter = $disk.DeviceID
                    SizeGB      = $sizeGB
                    FreeGB      = $freeGB
                    FreePercent = $freePercent
                    LowSpace    = ($freePercent -lt 15)
                }
            }
            catch { }
        }
    }
    catch { }

    $uptimeText = 'No disponible'
    try {
        $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        $uptimeText = '{0} dias, {1} horas, {2} minutos' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    }
    catch { }

    return [PSCustomObject]@{
        Hostname       = $hostname
        OsCaption      = $osCaption
        OsVersion      = $osVersion
        OsBuild        = $osBuild
        CpuName        = $cpuName
        RamTotalGB     = $ramTotalGB
        RamUsedGB      = $ramUsedGB
        RamUsedPercent = $ramUsedPercent
        Disks          = $disks
        UptimeText     = $uptimeText
    }
}

function Show-SystemInfo {
    <#
        Muestra por pantalla la informacion del sistema de forma clara
        y registra la consulta en el log.
    #>

    Write-Host ''
    Write-Host '=== INFORMACIÓN DEL SISTEMA ===' -ForegroundColor Cyan
    Write-Host ''

    $info = Get-ITSystemInfo

    Write-Host ('Nombre del equipo : {0}' -f $info.Hostname)
    Write-Host ('Sistema operativo : {0} (versión {1}, build {2})' -f $info.OsCaption, $info.OsVersion, $info.OsBuild)
    Write-Host ('Procesador        : {0}' -f $info.CpuName)
    Write-Host ('RAM total         : {0} GB' -f $info.RamTotalGB)
    Write-Host ('RAM en uso        : {0} GB ({1} %)' -f $info.RamUsedGB, $info.RamUsedPercent)
    Write-Host ('Tiempo encendido  : {0}' -f $info.UptimeText)

    Write-Host ''
    Write-Host 'Discos:' -ForegroundColor Cyan
    if ($info.Disks.Count -eq 0) {
        Write-Host '  No se ha podido leer información de discos.' -ForegroundColor DarkYellow
    }
    else {
        foreach ($disk in $info.Disks) {
            $color = if ($disk.LowSpace) { 'Red' } else { 'Green' }
            $aviso = if ($disk.LowSpace) { '  <-- AVISO: menos del 15% libre' } else { '' }
            Write-Host ('  {0} - Total: {1} GB / Libre: {2} GB ({3} %){4}' -f $disk.DriveLetter, $disk.SizeGB, $disk.FreeGB, $disk.FreePercent, $aviso) -ForegroundColor $color
        }
    }

    Write-Host ''

    Write-ITLog -Message 'Se ha consultado la información del sistema.' -Level 'INFO'
}

Export-ModuleMember -Function Get-ITSystemInfo, Show-SystemInfo

