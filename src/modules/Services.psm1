# Services.psm1
# Modulo que muestra el estado de servicios clave de Windows y ofrece
# acciones de administracion basica (reiniciar la cola de impresion,
# vaciar trabajos de impresion atascados).

$script:KeyServices = @(
    @{ Name = 'Spooler';   DisplayNameEs = 'Cola de impresión' },
    @{ Name = 'wuauserv';  DisplayNameEs = 'Windows Update' },
    @{ Name = 'Dnscache';  DisplayNameEs = 'Cliente DNS' },
    @{ Name = 'Dhcp';      DisplayNameEs = 'Cliente DHCP' },
    @{ Name = 'Audiosrv';  DisplayNameEs = 'Audio' }
)

function Get-ITKeyServicesStatus {
    <#
        Devuelve el estado (en ejecucion/detenido) y el tipo de inicio de
        los servicios clave. Un servicio que no se pueda leer no impide ver
        el resto.
    #>

    $statusList = @()

    foreach ($service in $script:KeyServices) {
        $state = Get-ITSafeValue {
            (Get-Service -Name $service.Name -ErrorAction Stop).Status.ToString()
        }
        $startMode = Get-ITSafeValue {
            (Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction Stop).StartMode
        }

        $statusList += [PSCustomObject]@{
            Name          = $service.Name
            DisplayNameEs = $service.DisplayNameEs
            State         = $state
            StartMode     = $startMode
        }
    }

    return $statusList
}

function Show-ITServicesStatus {
    <#
        Pinta la tabla de estado de los servicios clave y registra la
        consulta en el log.
    #>

    Write-Host ''
    Write-Host '=== ESTADO DE SERVICIOS CLAVE ===' -ForegroundColor Cyan
    Write-Host ''

    $statusList = Get-ITKeyServicesStatus

    foreach ($service in $statusList) {
        $color = if ($service.State -eq 'Running') { 'Green' } else { 'DarkYellow' }
        Write-Host ('  {0,-20} Estado: {1,-12} Inicio: {2}' -f $service.DisplayNameEs, $service.State, $service.StartMode) -ForegroundColor $color
    }

    Write-ITLog -Message 'Se ha consultado el estado de los servicios clave.' -Level 'INFO'
}

function Restart-ITPrintSpooler {
    <#
        Reinicia el servicio de cola de impresion. Requiere administrador.
    #>

    try {
        Restart-Service -Name 'Spooler' -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-ITLog -Message ('Error al reiniciar la cola de impresión: {0}' -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Clear-ITPrintQueue {
    <#
        Vacia los trabajos de impresion atascados: detiene la cola de
        impresion, borra el contenido de la carpeta de trabajos pendientes
        y vuelve a iniciar el servicio. El servicio se reinicia siempre,
        incluso si el borrado falla.
    #>

    $result = [PSCustomObject]@{
        Success       = $false
        DeletedCount  = 0
        SkippedCount  = 0
        ErrorMessage  = $null
    }

    try {
        Stop-Service -Name 'Spooler' -Force -ErrorAction Stop
    }
    catch {
        $result.ErrorMessage = 'No se ha podido detener la cola de impresión.'
        Write-ITLog -Message ('Error al detener la cola de impresión: {0}' -f $_.Exception.Message) -Level 'ERROR'
        return $result
    }

    try {
        $printersPath = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
        $items = Get-ChildItem -Path $printersPath -Force -ErrorAction SilentlyContinue

        foreach ($item in $items) {
            try {
                Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction Stop
                $result.DeletedCount++
            }
            catch {
                $result.SkippedCount++
            }
        }

        $result.Success = $true
    }
    finally {
        try {
            Start-Service -Name 'Spooler' -ErrorAction Stop
        }
        catch {
            $result.Success = $false
            $result.ErrorMessage = 'No se ha podido reiniciar la cola de impresión. Reinícialo manualmente o reinicia el equipo.'
            Write-ITLog -Message ('Error al reiniciar la cola de impresión tras vaciarla: {0}' -f $_.Exception.Message) -Level 'ERROR'
        }
    }

    return $result
}

function Show-ITServicesMenu {
    <#
        Submenu de la opcion 5: estado de servicios clave y acciones de
        administracion sobre la cola de impresion.
    #>

    $exitSubmenu = $false

    while (-not $exitSubmenu) {
        Show-ITServicesStatus

        Write-Host ''
        Write-Host ' 1. Reiniciar la cola de impresión                     [ADMIN]'
        Write-Host ' 2. Vaciar trabajos de impresión atascados             [ADMIN]'
        Write-Host ' 0. Volver al menú principal'
        Write-Host ''

        $choice = Read-Host 'Elige una opción'

        switch ($choice) {
            '1' {
                if (-not (Test-ITIsAdmin)) {
                    Show-ITAdminRequiredMessage -ActionName 'Reiniciar la cola de impresión'
                }
                elseif (Confirm-ITAction -Message 'Se va a reiniciar el servicio de cola de impresión.') {
                    if (Restart-ITPrintSpooler) {
                        Write-Host ''
                        Write-Host 'Cola de impresión reiniciada correctamente.' -ForegroundColor Green
                        Write-ITLog -Message 'Cola de impresión reiniciada.' -Level 'ACTION'
                    }
                    else {
                        Write-Host ''
                        Write-Host 'No se ha podido reiniciar la cola de impresión.' -ForegroundColor Red
                    }
                }
                else {
                    Write-ITLog -Message 'El usuario canceló el reinicio de la cola de impresión.' -Level 'WARN'
                }
            }
            '2' {
                if (-not (Test-ITIsAdmin)) {
                    Show-ITAdminRequiredMessage -ActionName 'Vaciar trabajos de impresión atascados'
                }
                elseif (Confirm-ITAction -Message 'Se perderán todos los trabajos de impresión pendientes.') {
                    $clearResult = Clear-ITPrintQueue
                    Write-Host ''
                    if ($clearResult.Success) {
                        Write-Host ('Cola de impresión vaciada: {0} trabajos borrados, {1} omitidos.' -f $clearResult.DeletedCount, $clearResult.SkippedCount) -ForegroundColor Green
                        Write-ITLog -Message ('Cola de impresión vaciada: {0} borrados, {1} omitidos.' -f $clearResult.DeletedCount, $clearResult.SkippedCount) -Level 'ACTION'
                    }
                    else {
                        Write-Host ('No se ha podido completar la operación: {0}' -f $clearResult.ErrorMessage) -ForegroundColor Red
                    }
                }
                else {
                    Write-ITLog -Message 'El usuario canceló el vaciado de la cola de impresión.' -Level 'WARN'
                }
            }
            '0' {
                $exitSubmenu = $true
            }
            default {
                Write-Host ''
                Write-Host 'Opción no válida.' -ForegroundColor Red
            }
        }

        if (-not $exitSubmenu) {
            Write-Host ''
            Read-Host 'Pulsa Enter para continuar' | Out-Null
        }
    }
}

Export-ModuleMember -Function Get-ITKeyServicesStatus, Show-ITServicesStatus, Restart-ITPrintSpooler, Clear-ITPrintQueue, Show-ITServicesMenu
