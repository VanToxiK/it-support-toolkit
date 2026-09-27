# Network.psm1
# Modulo de solo lectura que reune el estado de la red y ejecuta pruebas
# basicas de conectividad (ping, DNS e Internet), con una conclusion
# en lenguaje claro.

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

Export-ModuleMember -Function Get-ITNetworkInfo, Test-ITConnectivity, Get-ITConnectivityConclusion, Show-NetworkDiagnostics
