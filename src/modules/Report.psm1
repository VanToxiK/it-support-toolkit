# Report.psm1
# Modulo de solo lectura para la Opcion 7: genera un informe HTML autonomo
# (CSS incrustado, sin JavaScript, sin recursos externos, datos escapados)
# reutilizando los datos que ya calculan SystemInfo.psm1, Network.psm1,
# Services.psm1 y Software.psm1. Puede generarse con datos reales o
# anonimizados (hostname, IPs, puerta de enlace, DNS y nombres de adaptador
# sustituidos por valores genericos) para poder compartirlo con seguridad.

function ConvertTo-ITHtmlSafe {
    <#
        Escapa un valor para poder incrustarlo en HTML sin riesgo de romper
        el marcado ni de inyectar contenido. No depende de ensamblados
        externos (System.Web), solo de reemplazos de texto.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value
    )

    $text = if ($null -eq $Value) { '' } else { [string]$Value }

    $text = $text -replace '&', '&amp;'
    $text = $text -replace '<', '&lt;'
    $text = $text -replace '>', '&gt;'
    $text = $text -replace '"', '&quot;'
    $text = $text -replace "'", '&#39;'

    return $text
}

function Get-ITReportData {
    <#
        Reune en un unico objeto los datos que necesita el informe HTML,
        reutilizando las funciones Get-* de los demas modulos (no se
        duplica ninguna logica de recogida de datos). Si $Anonymize es
        $true, sustituye antes de devolver los datos identificativos:
        hostname, IPs de adaptadores, puerta de enlace, servidores DNS y
        nombres de adaptador.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Anonymize
    )

    $systemInfo = Get-ITSystemInfo
    $networkInfo = Get-ITNetworkInfo
    $connectivity = Test-ITConnectivity -GatewayIP $networkInfo.GatewayIP
    $conclusion = Get-ITConnectivityConclusion -TestResult $connectivity
    $services = Get-ITKeyServicesStatus
    $installedProgramsCount = (Get-ITInstalledPrograms).Count

    $hostname = $systemInfo.Hostname
    $gatewayIP = $networkInfo.GatewayIP
    $dnsServers = $networkInfo.DnsServers

    $adapters = @()
    $adapterNumber = 0
    foreach ($adapter in $networkInfo.Adapters) {
        $adapterNumber++

        $adapterName = $adapter.Name
        $adapterIPv4 = $adapter.IPv4

        if ($Anonymize) {
            $adapterName = 'Adaptador de red {0}' -f $adapterNumber
            if ($adapterIPv4 -ne 'No disponible') {
                $adapterIPv4 = '192.168.x.x'
            }
        }

        $adapters += [PSCustomObject]@{
            Name        = $adapterName
            Description = $adapter.Description
            IPv4        = $adapterIPv4
        }
    }

    if ($Anonymize) {
        $hostname = 'EQUIPO-01'

        if ($gatewayIP -ne 'No disponible') {
            $gatewayIP = '192.168.x.x'
        }

        $dnsServers = @(
            foreach ($dnsServer in $dnsServers) {
                if ($dnsServer -ne 'No disponible') { '192.168.x.x' } else { $dnsServer }
            }
        )
    }

    return [PSCustomObject]@{
        Version                 = Get-ITToolkitVersion
        GeneratedAt             = Get-Date
        Anonymized              = $Anonymize
        Hostname                = $hostname
        OsCaption               = $systemInfo.OsCaption
        OsVersion               = $systemInfo.OsVersion
        OsBuild                 = $systemInfo.OsBuild
        CpuName                 = $systemInfo.CpuName
        RamTotalGB              = $systemInfo.RamTotalGB
        RamUsedGB               = $systemInfo.RamUsedGB
        RamUsedPercent          = $systemInfo.RamUsedPercent
        UptimeText              = $systemInfo.UptimeText
        Disks                   = $systemInfo.Disks
        Adapters                = $adapters
        GatewayIP               = $gatewayIP
        DnsServers              = $dnsServers
        Connectivity            = $connectivity
        Conclusion              = $conclusion
        Services                = $services
        InstalledProgramsCount  = $installedProgramsCount
    }
}

function New-ITHtmlReportContent {
    <#
        Construye el HTML5 autonomo del informe a partir de los datos de
        Get-ITReportData: CSS incrustado, sin JavaScript, sin recursos
        externos y con todos los datos escapados con ConvertTo-ITHtmlSafe.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Data
    )

    $e = { param($Value) ConvertTo-ITHtmlSafe -Value $Value }

    $diskRows = if ($Data.Disks.Count -eq 0) {
        '<tr><td colspan="4">No se ha podido leer información de discos.</td></tr>'
    }
    else {
        ($Data.Disks | ForEach-Object {
            $rowClass = if ($_.LowSpace) { ' class="warning"' } else { '' }
            $aviso = if ($_.LowSpace) { ' &lt;-- AVISO: menos del 15% libre' } else { '' }
            '<tr{0}><td>{1}</td><td>{2} GB</td><td>{3} GB</td><td>{4} %{5}</td></tr>' -f `
                $rowClass, (& $e $_.DriveLetter), (& $e $_.SizeGB), (& $e $_.FreeGB), (& $e $_.FreePercent), $aviso
        }) -join "`n"
    }

    $adapterRows = if ($Data.Adapters.Count -eq 0) {
        '<tr><td colspan="3">No se ha detectado ningún adaptador activo.</td></tr>'
    }
    else {
        ($Data.Adapters | ForEach-Object {
            '<tr><td>{0}</td><td>{1}</td><td>{2}</td></tr>' -f (& $e $_.Name), (& $e $_.Description), (& $e $_.IPv4)
        }) -join "`n"
    }

    $dnsServersText = & $e (($Data.DnsServers -join ', '))

    $serviceRows = ($Data.Services | ForEach-Object {
        $rowClass = if ($_.State -eq 'Running') { ' class="ok"' } else { ' class="warning"' }
        '<tr{0}><td>{1}</td><td>{2}</td><td>{3}</td></tr>' -f `
            $rowClass, (& $e $_.DisplayNameEs), (& $e $_.State), (& $e $_.StartMode)
    }) -join "`n"

    $connectivityRows = @(
        @{ Label = 'Ping a la puerta de enlace'; Ok = $Data.Connectivity.PingOk }
        @{ Label = 'Resolución DNS'; Ok = $Data.Connectivity.DnsOk }
        @{ Label = 'Conexión a Internet'; Ok = $Data.Connectivity.InternetOk }
    ) | ForEach-Object {
        $rowClass = if ($_.Ok) { ' class="ok"' } else { ' class="warning"' }
        $text = if ($_.Ok) { 'OK' } else { 'FALLA' }
        '<tr{0}><td>{1}</td><td>{2}</td></tr>' -f $rowClass, (& $e $_.Label), $text
    }
    $connectivityRowsText = $connectivityRows -join "`n"

    $anonymizedText = if ($Data.Anonymized) { 'Sí' } else { 'No' }
    $generatedAtText = & $e ($Data.GeneratedAt.ToString('dd/MM/yyyy HH:mm:ss'))

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Informe IT Support Toolkit</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: Segoe UI, Arial, sans-serif;
    color: #1f2933;
    background-color: #ffffff;
    margin: 0;
    padding: 0 1.5rem 2rem;
  }
  header {
    background-color: #1f3a5f;
    color: #ffffff;
    padding: 1.5rem;
    margin: 0 -1.5rem 1.5rem;
  }
  header h1 { margin: 0 0 0.25rem; font-size: 1.5rem; }
  header p { margin: 0.15rem 0; font-size: 0.9rem; }
  section { margin-bottom: 1.75rem; }
  h2 {
    font-size: 1.1rem;
    border-bottom: 2px solid #1f3a5f;
    padding-bottom: 0.25rem;
    color: #1f3a5f;
  }
  table { border-collapse: collapse; width: 100%; margin-top: 0.5rem; }
  th, td { border: 1px solid #d3dce6; padding: 0.4rem 0.6rem; text-align: left; font-size: 0.9rem; }
  th { background-color: #eef2f7; }
  tr.warning { background-color: #fdecea; color: #92221a; font-weight: bold; }
  tr.ok { background-color: #eaf7ee; }
  .conclusion {
    margin-top: 0.75rem;
    padding: 0.75rem 1rem;
    background-color: #eef2f7;
    border-left: 4px solid #1f3a5f;
  }
  footer {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #d3dce6;
    font-size: 0.8rem;
    color: #52606d;
    font-style: italic;
  }
  @media print {
    header { background-color: #ffffff !important; color: #1f3a5f !important; border-bottom: 2px solid #1f3a5f; }
    tr.warning, tr.ok { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>

<header>
  <h1>IT Support Toolkit</h1>
  <p>Versión $(& $e $Data.Version) &mdash; Informe generado el $generatedAtText</p>
  <p>Equipo: $(& $e $Data.Hostname) &mdash; Datos anonimizados: $anonymizedText</p>
</header>

<main>

<section id="sistema">
  <h2>Sistema</h2>
  <table>
    <tr><th>Nombre del equipo</th><td>$(& $e $Data.Hostname)</td></tr>
    <tr><th>Sistema operativo</th><td>$(& $e $Data.OsCaption) (versión $(& $e $Data.OsVersion), build $(& $e $Data.OsBuild))</td></tr>
    <tr><th>Procesador</th><td>$(& $e $Data.CpuName)</td></tr>
    <tr><th>RAM total</th><td>$(& $e $Data.RamTotalGB) GB</td></tr>
    <tr><th>RAM en uso</th><td>$(& $e $Data.RamUsedGB) GB ($(& $e $Data.RamUsedPercent) %)</td></tr>
    <tr><th>Tiempo encendido</th><td>$(& $e $Data.UptimeText)</td></tr>
  </table>
</section>

<section id="discos">
  <h2>Recursos y discos</h2>
  <table>
    <tr><th>Unidad</th><th>Tamaño</th><th>Libre</th><th>% libre</th></tr>
    $diskRows
  </table>
</section>

<section id="red">
  <h2>Red</h2>
  <table>
    <tr><th>Adaptador</th><th>Descripción</th><th>IPv4</th></tr>
    $adapterRows
  </table>
  <table>
    <tr><th>Puerta de enlace</th><td>$(& $e $Data.GatewayIP)</td></tr>
    <tr><th>Servidores DNS</th><td>$dnsServersText</td></tr>
  </table>
  <table>
    <tr><th>Prueba</th><th>Resultado</th></tr>
    $connectivityRowsText
  </table>
  <p class="conclusion">Conclusión: $(& $e $Data.Conclusion)</p>
</section>

<section id="servicios">
  <h2>Servicios clave</h2>
  <table>
    <tr><th>Servicio</th><th>Estado</th><th>Tipo de inicio</th></tr>
    $serviceRows
  </table>
</section>

<section id="programas">
  <h2>Programas instalados</h2>
  <p>Número de programas instalados: <strong>$(& $e $Data.InstalledProgramsCount)</strong></p>
</section>

</main>

<footer>
  <p>Informe generado por IT Support Toolkit v$(& $e $Data.Version). Los datos reflejan el estado del
  equipo en el momento de la generación y pueden quedar desactualizados. Si no se ha
  anonimizado, este informe puede contener información sensible (nombre de equipo, direcciones IP,
  programas instalados): compártelo con precaución.</p>
</footer>

</body>
</html>
"@

    return $html
}

function Get-ITReportsFolder {
    <#
        Devuelve la ruta de la carpeta de informes en Documentos, creandola
        si no existe todavia. Es una carpeta independiente de la logica de
        Export-ITInstalledProgramsCsv (Software.psm1): no se modifica ese
        modulo, solo se reutiliza la misma ruta de destino.
    #>

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $reportsFolder = Join-Path $documentsPath 'IT Support Toolkit Reports'

    if (-not (Test-Path -Path $reportsFolder)) {
        New-Item -Path $reportsFolder -ItemType Directory -Force | Out-Null
    }

    return $reportsFolder
}

function Show-ITHtmlReport {
    <#
        Orquesta la Opcion 7: pregunta si se quiere anonimizar, genera el
        informe HTML, lo guarda en Documentos\IT Support Toolkit Reports y
        ofrece abrirlo. Registra la accion en el log.
    #>

    Write-Host ''
    Write-Host '=== INFORME HTML ===' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '¿Ocultar datos identificativos para compartir el informe? (S/N)' -ForegroundColor Yellow
    $answer = Read-Host '¿Anonimizar? (S/N)'
    $anonymize = ($answer -eq 'S' -or $answer -eq 's')

    Write-Host ''
    Write-Host 'Generando el informe, esto puede tardar unos segundos (se comprueba la conexión de red)...' -ForegroundColor Yellow

    $data = Get-ITReportData -Anonymize $anonymize
    $htmlContent = New-ITHtmlReportContent -Data $data

    try {
        $reportsFolder = Get-ITReportsFolder
        $fileName = 'informe-{0}.html' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        $filePath = Join-Path $reportsFolder $fileName

        [System.IO.File]::WriteAllText($filePath, $htmlContent, (New-Object System.Text.UTF8Encoding($false)))

        Write-Host ''
        Write-Host ('Informe generado en: {0}' -f $filePath) -ForegroundColor Green
        Write-ITLog -Message ('Informe HTML generado: {0} (anonimizado: {1}).' -f $filePath, $anonymize) -Level 'ACTION'

        if (Confirm-ITAction -Message '¿Quieres abrir el informe ahora?') {
            try {
                Start-Process -FilePath $filePath -ErrorAction Stop
            }
            catch {
                Write-Host 'No se ha podido abrir el informe automáticamente. Ábrelo manualmente desde la ruta indicada.' -ForegroundColor DarkYellow
                Write-ITLog -Message ('No se ha podido abrir automáticamente el informe: {0}' -f $_.Exception.Message) -Level 'ERROR'
            }
        }
    }
    catch {
        Write-Host ''
        Write-Host 'No se ha podido generar el informe HTML.' -ForegroundColor Red
        Write-ITLog -Message ('Error al generar el informe HTML: {0}' -f $_.Exception.Message) -Level 'ERROR'
    }
}

Export-ModuleMember -Function ConvertTo-ITHtmlSafe, Get-ITReportData, New-ITHtmlReportContent, Show-ITHtmlReport
