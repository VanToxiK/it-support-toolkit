# Network.psm1
# Modulo que reune el estado de la red, ejecuta pruebas basicas de
# conectividad (ping, DNS e Internet) con una conclusion en lenguaje claro,
# y ofrece acciones de reparacion basica: vaciar cache DNS, renovar la
# concesion DHCP del adaptador principal y reiniciar dicho adaptador.

function Write-ITStatusLine {
    <#
        Imprime una linea "Etiqueta: OK/FALLA" con color segun el resultado.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [bool]$Ok
    )

    $text = if ($Ok) { 'OK' } else { 'FALLA' }
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ('{0,-28}: {1}' -f $Label, $text) -ForegroundColor $color
}

function Get-ITNetworkInfo {
    <#
        Devuelve adaptadores activos, la puerta de enlace principal
        (la de menor metrica, por si hay VPN u otros adaptadores virtuales)
        y los servidores DNS de esa conexion.
    #>

    $adapters = @()
    try {
        $upAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($adapter in $upAdapters) {
            try {
                $ipv4 = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -notlike '169.254.*' } |
                    Select-Object -First 1 -ExpandProperty IPAddress

                $adapters += [PSCustomObject]@{
                    Name           = $adapter.Name
                    Description    = $adapter.InterfaceDescription
                    IPv4           = if ($ipv4) { $ipv4 } else { 'No disponible' }
                    InterfaceIndex = $adapter.ifIndex
                }
            }
            catch { }
        }
    }
    catch { }

    $gatewayIP = 'No disponible'
    $gatewayInterfaceIndex = $null
    try {
        $defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object -Property RouteMetric |
            Select-Object -First 1

        if ($defaultRoute) {
            $gatewayIP = $defaultRoute.NextHop
            $gatewayInterfaceIndex = $defaultRoute.InterfaceIndex
        }
    }
    catch { }

    $dnsServers = @('No disponible')
    try {
        if ($gatewayInterfaceIndex) {
            $dnsConfig = Get-DnsClientServerAddress -InterfaceIndex $gatewayInterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($dnsConfig -and $dnsConfig.ServerAddresses.Count -gt 0) {
                $dnsServers = $dnsConfig.ServerAddresses
            }
        }
    }
    catch { }

    return [PSCustomObject]@{
        Adapters              = $adapters
        GatewayIP             = $gatewayIP
        GatewayInterfaceIndex = $gatewayInterfaceIndex
        DnsServers            = $dnsServers
    }
}

function Test-ITConnectivity {
    <#
        Ejecuta tres pruebas independientes:
        - Ping a la puerta de enlace.
        - Resolucion DNS de un dominio conocido.
        - Conexion a Internet por el puerto 443 (independiente del DNS,
          usa una IP directa).
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$GatewayIP
    )

    $pingOk = $false
    if ($GatewayIP -and $GatewayIP -ne 'No disponible') {
        try {
            $pingOk = Test-Connection -ComputerName $GatewayIP -Count 2 -Quiet -ErrorAction SilentlyContinue
        }
        catch {
            $pingOk = $false
        }
    }

    $dnsOk = $false
    try {
        $null = Resolve-DnsName -Name 'www.google.com' -ErrorAction Stop
        $dnsOk = $true
    }
    catch {
        $dnsOk = $false
    }

    $internetOk = $false
    try {
        $internetOk = Test-NetConnection -ComputerName '8.8.8.8' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    }
    catch {
        $internetOk = $false
    }

    return [PSCustomObject]@{
        PingOk     = [bool]$pingOk
        DnsOk      = $dnsOk
        InternetOk = [bool]$internetOk
    }
}

function Get-ITConnectivityConclusion {
    <#
        Traduce la combinacion de resultados a una frase en castellano llano.
        Un fallo de ping con DNS e Internet funcionando no significa que no
        haya conexion: normalmente es que el router no responde a ping (ICMP).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$TestResult
    )

    $ping = $TestResult.PingOk
    $dns = $TestResult.DnsOk
    $internet = $TestResult.InternetOk

    if ($ping -and $dns -and $internet) {
        return 'Todo funciona correctamente: hay conexión con el router, DNS e Internet.'
    }
    if ((-not $ping) -and $dns -and $internet) {
        return 'Hay conexión a Internet; el router probablemente no responde a ping (ICMP bloqueado), no es un problema real de conectividad.'
    }
    if ($ping -and (-not $dns) -and $internet) {
        return 'Hay conexión con el router e Internet, pero falla la resolución de nombres DNS (revisa los servidores DNS configurados).'
    }
    if ($ping -and $dns -and (-not $internet)) {
        return 'Hay conexión con el router y el DNS funciona, pero no se puede salir a Internet (posible bloqueo de firewall o proxy).'
    }
    if ($ping -and (-not $dns) -and (-not $internet)) {
        return 'Hay conexión con el router, pero fallan tanto el DNS como la salida a Internet.'
    }
    if ((-not $ping) -and (-not $dns) -and $internet) {
        return 'Hay salida a Internet aunque el ping y la resolución DNS han fallado; revisa la configuración de red o el firewall local.'
    }
    if ((-not $ping) -and $dns -and (-not $internet)) {
        return 'La resolución DNS funciona, pero no hay conexión con el router ni salida a Internet.'
    }

    return 'No hay conexión con la puerta de enlace: revisa el cable de red o el Wi-Fi.'
}

function Show-NetworkDiagnostics {
    <#
        Muestra la informacion de red, ejecuta las pruebas de conectividad
        y da una conclusion en lenguaje claro. Registra la consulta en el log.
    #>

    Write-Host ''
    Write-Host '=== DIAGNÓSTICO DE RED ===' -ForegroundColor Cyan
    Write-Host ''

    $info = Get-ITNetworkInfo

    Write-Host 'Adaptadores activos:'
    if ($info.Adapters.Count -eq 0) {
        Write-Host '  No se ha detectado ningún adaptador activo.' -ForegroundColor DarkYellow
    }
    else {
        foreach ($adapter in $info.Adapters) {
            Write-Host ('  {0} ({1}) - IPv4: {2}' -f $adapter.Name, $adapter.Description, $adapter.IPv4)
        }
    }

    Write-Host ''
    Write-Host ('Puerta de enlace : {0}' -f $info.GatewayIP)
    Write-Host ('Servidores DNS   : {0}' -f ($info.DnsServers -join ', '))

    Write-Host ''
    Write-Host 'Comprobando conexión...' -ForegroundColor Yellow

    $testResult = Test-ITConnectivity -GatewayIP $info.GatewayIP

    Write-Host ''
    Write-ITStatusLine -Label 'Ping a la puerta de enlace' -Ok $testResult.PingOk
    Write-ITStatusLine -Label 'Resolución DNS' -Ok $testResult.DnsOk
    Write-ITStatusLine -Label 'Conexión a Internet' -Ok $testResult.InternetOk

    $conclusion = Get-ITConnectivityConclusion -TestResult $testResult

    Write-Host ''
    Write-Host ('Conclusión: {0}' -f $conclusion) -ForegroundColor Cyan
    Write-Host ''

    Write-ITLog -Message 'Se ha ejecutado el diagnóstico de red.' -Level 'INFO'
}

function Clear-ITDnsCache {
    <#
        Vacia la cache de resolucion DNS local. No requiere permisos de
        administrador. Devuelve $true si ha ido bien.
    #>

    try {
        Clear-DnsClientCache -ErrorAction Stop
        return $true
    }
    catch {
        Write-ITLog -Message ('Error al vaciar la caché DNS: {0}' -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Update-ITMainAdapterDhcp {
    <#
        Renueva de verdad la asignacion DHCP del adaptador principal (el de
        la ruta por defecto de menor metrica): libera y vuelve a solicitar
        la IP al servidor DHCP mediante ReleaseDHCPLease/RenewDHCPLease de
        Win32_NetworkAdapterConfiguration (via Invoke-CimMethod). Esto NO
        reinicia el adaptador, solo renueva la concesion de IP.
        Si el adaptador tiene IP estatica (sin DHCP), no hace nada y lo
        explica. Requiere permisos de administrador.
    #>

    $result = [PSCustomObject]@{
        Success      = $false
        AdapterName  = $null
        IsStatic     = $false
        ErrorMessage = $null
    }

    $networkInfo = Get-ITNetworkInfo
    $interfaceIndex = $networkInfo.GatewayInterfaceIndex

    if (-not $interfaceIndex) {
        $result.ErrorMessage = 'No se ha podido identificar el adaptador de red principal.'
        return $result
    }

    try {
        $result.AdapterName = (Get-NetAdapter -InterfaceIndex $interfaceIndex -ErrorAction Stop).Name
    }
    catch {
        $result.ErrorMessage = 'El adaptador de red principal ya no está disponible.'
        return $result
    }

    try {
        $adapterConfig = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex=$interfaceIndex" -ErrorAction Stop
    }
    catch {
        $result.ErrorMessage = 'No se ha podido leer la configuración IP del adaptador principal.'
        Write-ITLog -Message ('Error al leer Win32_NetworkAdapterConfiguration: {0}' -f $_.Exception.Message) -Level 'ERROR'
        return $result
    }

    if (-not $adapterConfig) {
        $result.ErrorMessage = 'No se ha podido encontrar la configuración IP del adaptador principal.'
        return $result
    }

    if (-not $adapterConfig.DHCPEnabled) {
        $result.IsStatic = $true
        $result.ErrorMessage = 'El adaptador principal tiene una IP fija (sin DHCP); no hay ninguna concesión que renovar.'
        return $result
    }

    try {
        # Invoke-CimMethod no lanza excepcion solo porque el metodo falle:
        # hay que comprobar su ReturnValue (0 = correcto) explicitamente.
        $releaseResult = Invoke-CimMethod -InputObject $adapterConfig -MethodName ReleaseDHCPLease -ErrorAction Stop
        if ($releaseResult.ReturnValue -ne 0) {
            throw "ReleaseDHCPLease devolvió el código de error $($releaseResult.ReturnValue)."
        }

        Start-Sleep -Seconds 2

        $renewResult = Invoke-CimMethod -InputObject $adapterConfig -MethodName RenewDHCPLease -ErrorAction Stop
        if ($renewResult.ReturnValue -ne 0) {
            throw "RenewDHCPLease devolvió el código de error $($renewResult.ReturnValue)."
        }

        $result.Success = $true
    }
    catch {
        $result.ErrorMessage = 'No se ha podido renovar la concesión DHCP del adaptador principal.'
        Write-ITLog -Message ('Error al renovar DHCP del adaptador principal: {0}' -f $_.Exception.Message) -Level 'ERROR'
    }

    return $result
}

function Restart-ITMainAdapter {
    <#
        Reinicia por completo el adaptador principal (el de la ruta por
        defecto de menor metrica) desactivandolo y volviendolo a activar.
        Se identifica el adaptador con -InputObject (el objeto que devuelve
        Get-NetAdapter), no con -InterfaceIndex: Disable-NetAdapter y
        Enable-NetAdapter no tienen ese parametro (solo -Name,
        -InterfaceDescription o -InputObject); usarlo hacia que ambos
        cmdlets fallaran siempre con un error de "parametro no reconocido".
        Se garantiza con try/finally que se intenta reactivar el adaptador
        aunque algo falle, para no dejar al usuario sin conexion. Tras
        reactivarlo, el adaptador puede tardar unos segundos en negociar el
        enlace, asi que se comprueba varias veces (hasta 20 segundos) en
        lugar de dar por bueno el resultado justo despues de Enable-NetAdapter.
        Requiere permisos de administrador.
    #>

    $result = [PSCustomObject]@{
        Success      = $false
        AdapterName  = $null
        FinalStatus  = $null
        ErrorMessage = $null
    }

    $networkInfo = Get-ITNetworkInfo
    $interfaceIndex = $networkInfo.GatewayInterfaceIndex

    if (-not $interfaceIndex) {
        $result.ErrorMessage = 'No se ha podido identificar el adaptador de red principal.'
        return $result
    }

    try {
        $adapter = Get-NetAdapter -InterfaceIndex $interfaceIndex -ErrorAction Stop
        $result.AdapterName = $adapter.Name
    }
    catch {
        $result.ErrorMessage = 'El adaptador de red principal ya no está disponible.'
        return $result
    }

    $disableErrorMessage = $null

    try {
        Disable-NetAdapter -InputObject $adapter -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 3
    }
    catch {
        $disableErrorMessage = 'No se ha podido desactivar el adaptador de red.'
        Write-ITLog -Message ('Error al desactivar el adaptador principal: {0}' -f $_.Exception.Message) -Level 'ERROR'
    }
    finally {
        # Se intenta reactivar SIEMPRE, tanto si la desactivacion fue bien
        # como si fallo, para no dejar el adaptador apagado.
        try {
            Enable-NetAdapter -InputObject $adapter -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-ITLog -Message ('Error al reactivar el adaptador principal: {0}' -f $_.Exception.Message) -Level 'ERROR'
        }

        Write-Host 'Esperando a que el adaptador se reconecte…' -ForegroundColor Yellow

        $maxWaitSeconds = 20
        $intervalSeconds = 2
        $waitedSeconds = 0
        $currentStatus = $null

        while ($waitedSeconds -lt $maxWaitSeconds) {
            Start-Sleep -Seconds $intervalSeconds
            $waitedSeconds += $intervalSeconds

            try {
                $currentStatus = (Get-NetAdapter -InterfaceIndex $interfaceIndex -ErrorAction Stop).Status
            }
            catch {
                $currentStatus = $null
            }

            if ($currentStatus -eq 'Up') {
                break
            }
        }

        # Se distinguen tres casos segun el estado final del adaptador:
        # sigue desactivado, se reactivo pero aun sin enlace, o todo bien.
        if ($currentStatus -eq 'Up') {
            $result.Success = $true
            $result.FinalStatus = 'Up'
            $result.ErrorMessage = $null
        }
        elseif ($currentStatus -eq 'Disabled') {
            $result.Success = $false
            $result.FinalStatus = 'StillDisabled'
            $result.ErrorMessage = 'El adaptador sigue desactivado. Actívalo manualmente desde "Configuración de red" o reinicia el equipo.'
        }
        else {
            $result.Success = $false
            $result.FinalStatus = 'NoLink'
            $result.ErrorMessage = 'El adaptador se ha reactivado pero todavía no tiene conexión. Puede tardar unos segundos más, o revisa el cable de red o el Wi-Fi.'
        }

        if ($disableErrorMessage -and -not $result.Success) {
            $result.ErrorMessage = '{0} {1}' -f $disableErrorMessage, $result.ErrorMessage
        }
    }

    return $result
}

function Show-ITNetworkRepairMenu {
    <#
        Submenu de la opcion 3: reparacion basica de red.
    #>

    $exitSubmenu = $false

    while (-not $exitSubmenu) {
        Write-Host ''
        Write-Host '=== REPARACIÓN BÁSICA DE RED ===' -ForegroundColor Cyan
        Write-Host ''
        Write-Host ' 1. Vaciar caché DNS'
        Write-Host ' 2. Renovar IP (DHCP) del adaptador principal      [ADMIN]'
        Write-Host ' 3. Reiniciar adaptador de red principal           [ADMIN]'
        Write-Host ' 4. Volver a ejecutar diagnóstico de red'
        Write-Host ' 0. Volver al menú principal'
        Write-Host ''

        $choice = Read-Host 'Elige una opción'

        switch ($choice) {
            '1' {
                if (Confirm-ITAction -Message 'Se va a vaciar la caché de resolución DNS local.') {
                    if (Clear-ITDnsCache) {
                        Write-Host ''
                        Write-Host 'Caché DNS vaciada correctamente.' -ForegroundColor Green
                        Write-ITLog -Message 'Caché DNS vaciada.' -Level 'ACTION'
                    }
                    else {
                        Write-Host ''
                        Write-Host 'No se ha podido vaciar la caché DNS.' -ForegroundColor Red
                    }
                }
                else {
                    Write-ITLog -Message 'El usuario canceló el vaciado de la caché DNS.' -Level 'WARN'
                }
            }
            '2' {
                if (-not (Test-ITIsAdmin)) {
                    Show-ITAdminRequiredMessage -ActionName 'Renovar IP (DHCP) del adaptador principal'
                }
                elseif (Confirm-ITAction -Message 'Se va a renovar la concesión DHCP del adaptador principal; la conexión podría cortarse brevemente.') {
                    $dhcpResult = Update-ITMainAdapterDhcp
                    Write-Host ''
                    if ($dhcpResult.Success) {
                        Write-Host ('IP renovada correctamente en el adaptador "{0}".' -f $dhcpResult.AdapterName) -ForegroundColor Green
                        Write-ITLog -Message ('IP DHCP renovada en el adaptador principal: {0}' -f $dhcpResult.AdapterName) -Level 'ACTION'
                    }
                    elseif ($dhcpResult.IsStatic) {
                        Write-Host $dhcpResult.ErrorMessage -ForegroundColor DarkYellow
                        Write-ITLog -Message ('Renovación DHCP omitida: el adaptador principal tiene IP fija ({0}).' -f $dhcpResult.AdapterName) -Level 'INFO'
                    }
                    else {
                        Write-Host ('No se ha podido completar la operación: {0}' -f $dhcpResult.ErrorMessage) -ForegroundColor Red
                        Write-ITLog -Message ('Fallo al renovar DHCP del adaptador principal: {0}' -f $dhcpResult.ErrorMessage) -Level 'ERROR'
                    }
                }
                else {
                    Write-ITLog -Message 'El usuario canceló la renovación DHCP del adaptador principal.' -Level 'WARN'
                }
            }
            '3' {
                if (-not (Test-ITIsAdmin)) {
                    Show-ITAdminRequiredMessage -ActionName 'Reiniciar adaptador de red principal'
                }
                elseif (Confirm-ITAction -Message 'Se va a reiniciar el adaptador de red principal y la conexión se cortará unos segundos. Si estás conectado a este equipo por Escritorio remoto, perderás la conexión y no podrás volver a entrar hasta que el adaptador se reactive.') {
                    $restartResult = Restart-ITMainAdapter
                    Write-Host ''
                    switch ($restartResult.FinalStatus) {
                        'Up' {
                            Write-Host ('Adaptador "{0}" reiniciado correctamente: conexión restablecida.' -f $restartResult.AdapterName) -ForegroundColor Green
                            Write-ITLog -Message ('Adaptador principal reiniciado correctamente: {0}' -f $restartResult.AdapterName) -Level 'ACTION'
                        }
                        'NoLink' {
                            Write-Host ('El adaptador "{0}" se reactivó, pero todavía no tiene conexión: {1}' -f $restartResult.AdapterName, $restartResult.ErrorMessage) -ForegroundColor DarkYellow
                            Write-ITLog -Message ('Adaptador principal reactivado sin enlace todavía: {0}' -f $restartResult.AdapterName) -Level 'WARN'
                        }
                        'StillDisabled' {
                            Write-Host ('No se ha podido reiniciar el adaptador "{0}": {1}' -f $restartResult.AdapterName, $restartResult.ErrorMessage) -ForegroundColor Red
                            Write-ITLog -Message ('Adaptador principal sigue desactivado tras el intento de reinicio: {0}' -f $restartResult.AdapterName) -Level 'ERROR'
                        }
                        default {
                            Write-Host ('No se ha podido completar la operación: {0}' -f $restartResult.ErrorMessage) -ForegroundColor Red
                            Write-ITLog -Message ('Fallo al reiniciar el adaptador principal: {0}' -f $restartResult.ErrorMessage) -Level 'ERROR'
                        }
                    }
                }
                else {
                    Write-ITLog -Message 'El usuario canceló el reinicio del adaptador de red principal.' -Level 'WARN'
                }
            }
            '4' {
                Show-NetworkDiagnostics
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

Export-ModuleMember -Function Get-ITNetworkInfo, Test-ITConnectivity, Get-ITConnectivityConclusion, Show-NetworkDiagnostics, Clear-ITDnsCache, Update-ITMainAdapterDhcp, Restart-ITMainAdapter, Show-ITNetworkRepairMenu
