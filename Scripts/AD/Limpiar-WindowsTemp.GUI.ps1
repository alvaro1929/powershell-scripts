<#  Cleanup-WindowsTemp.GUI.ps1
    Limpieza de temporales y componentes con interfaz gráfica.
    - Elige días de antigüedad
    - Incluir TEMP de todos los usuarios
    - Modo agresivo (SoftwareDistribution/Delivery Optimization)
    - DISM /ResetBase
    - Modo simulación (WhatIf)
    - Log automático en C:\Logs

    Requiere: PowerShell en Windows con .NET (GUI). En Server Core, usa la versión sin GUI.


    Lanzar con: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    C:\Scripts\Cleanup-WindowsTemp.GUI.ps1


#>

[CmdletBinding(SupportsShouldProcess=$true)]
param()

#--- Funciones comunes ---------------------------------------------------------
function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  "[$ts][$Level] $Message" | Tee-Object -FilePath $Global:LogFile -Append
}

function Remove-OldItems {
  param(
    [Parameter(Mandatory)][string]$Path,
    [int]$OlderThanDays = 7,
    [switch]$AllFiles
  )
  if (-not (Test-Path $Path)) { Write-Log "No existe: $Path"; return }
  try {
    $threshold = (Get-Date).AddDays(-$OlderThanDays)
    $items = if ($AllFiles) {
      Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
    } else {
      Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt $threshold
      }
    }
    $count = 0
    foreach ($i in $items) {
      if ($PSCmdlet.ShouldProcess($i.FullName, "Remove")) {
        try { Remove-Item -LiteralPath $i.FullName -Force -Recurse -ErrorAction Stop; $count++ }
        catch { Write-Log "No se pudo borrar: $($i.FullName) -> $($_.Exception.Message)" "WARN" }
      }
    }
    Write-Log "Borrados $count elemento(s) en $Path"
  } catch {
    Write-Log "Error en $Path -> $($_.Exception.Message)" "ERROR"
  }
}

function Do-Cleanup {
  param(
    [int]$Days,
    [switch]$IncludeUserTemps,
    [switch]$Aggressive,
    [switch]$ResetBase,
    [switch]$WhatIf
  )

  $Global:LogFile = Join-Path 'C:\Logs' ("Cleanup-{0}.log" -f (Get-Date).ToString('yyyyMMdd_HHmm'))
  if (-not (Test-Path 'C:\Logs')) { New-Item -ItemType Directory -Path 'C:\Logs' | Out-Null }

  Write-Log "Inicio limpieza. Days=$Days IncludeUserTemps=$IncludeUserTemps Aggressive=$Aggressive ResetBase=$ResetBase WhatIf=$WhatIf"

  # 1) Temp del usuario actual (todo)
  $userTemp = [IO.Path]::GetTempPath()
  Write-Log "Limpiando TEMP usuario: $userTemp"
  if ($WhatIf) { $PSCmdlet.WhatIfPreference = $true }
  Remove-OldItems -Path $userTemp -AllFiles

  # 2) C:\Windows\Temp (>Days)
  $winTemp = 'C:\Windows\Temp'
  Write-Log "Limpiando Windows Temp (> $Days días): $winTemp"
  Remove-OldItems -Path $winTemp -OlderThanDays $Days

  # 3) Temp de todos los usuarios (opcional)
  if ($IncludeUserTemps) {
    Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $p = Join-Path $_.FullName 'AppData\Local\Temp'
      Write-Log "Limpiando Temp perfil: $p"
      Remove-OldItems -Path $p -OlderThanDays $Days
    }
  }

  # 4) Papelera
  try {
    Write-Log "Vaciando Papelera…"
    if (-not $WhatIf) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
    Write-Log "Papelera vaciada."
  } catch { Write-Log "Error vaciando Papelera -> $($_.Exception.Message)" "WARN" }

  # 5) Modo agresivo
  if ($Aggressive) {
    try {
      Write-Log "AGGRESSIVE: limpiando SoftwareDistribution y Delivery Optimization"
      $services = 'wuauserv','bits'
      if (-not $WhatIf) { foreach ($s in $services) { Stop-Service $s -Force -ErrorAction SilentlyContinue } }

      Remove-OldItems -Path 'C:\Windows\SoftwareDistribution\Download' -AllFiles
      Remove-OldItems -Path 'C:\Windows\SoftwareDistribution\DataStore\Logs' -OlderThanDays $Days
      Remove-OldItems -Path 'C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache' -AllFiles

      if (-not $WhatIf) { foreach ($s in $services) { Start-Service $s -ErrorAction SilentlyContinue } }
      Write-Log "Limpieza agresiva completada."
    } catch { Write-Log "Error en limpieza agresiva -> $($_.Exception.Message)" "ERROR" }
  }

  # 6) DISM
  try {
    $args = '/Online','/Cleanup-Image','/StartComponentCleanup'
    if ($ResetBase) { $args += '/ResetBase' }
    Write-Log ("Ejecutando DISM {0}" -f ($args -join ' '))
    if (-not $WhatIf) {
      $p = Start-Process -FilePath dism.exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
      Write-Log "DISM finalizado con código $($p.ExitCode)"
    } else {
      Write-Log "DISM simulado (WhatIf)."
    }
  } catch { Write-Log "Error ejecutando DISM -> $($_.Exception.Message)" "ERROR" }

  Write-Log "Limpieza finalizada."
}

#--- Requiere admin ------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  Write-Host "Ejecuta este script como **Administrador**." -ForegroundColor Yellow
  exit 1
}

#--- Intentar cargar GUI; si falla, usar prompts en consola --------------------
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
} catch {
  Write-Host "Entorno sin GUI. Usando preguntas en consola..." -ForegroundColor Yellow
  $days = [int](Read-Host "Días de antigüedad para borrar en Windows\Temp (recomendado 7)")
  $incUsers = (Read-Host "¿Incluir Temp de todos los usuarios? (s/n)") -match 's'
  $aggr = (Read-Host "¿Modo agresivo Windows Update/DO? (s/n)") -match 's'
  $reset = (Read-Host "¿DISM con /ResetBase? (s/n)") -match 's'
  $whatif = (Read-Host "¿Simulación (WhatIf)? (s/n)") -match 's'
  Do-Cleanup -Days $days -IncludeUserTemps:$incUsers -Aggressive:$aggr -ResetBase:$reset -WhatIf:$whatif
  exit 0
}

#--- Construir ventana ---------------------------------------------------------
$form             = New-Object System.Windows.Forms.Form
$form.Text        = "Limpieza de Windows (BG Tec)"
$form.Size        = New-Object System.Drawing.Size(430, 360)
$form.StartPosition = "CenterScreen"
$form.TopMost     = $true

$lblDays = New-Object System.Windows.Forms.Label
$lblDays.Text = "Borrar en C:\Windows\Temp archivos con más de (días):"
$lblDays.AutoSize = $true
$lblDays.Location = '15,20'

$numDays = New-Object System.Windows.Forms.NumericUpDown
$numDays.Location = '20,45'
$numDays.Width = 80
$numDays.Minimum = 0
$numDays.Maximum = 365
$numDays.Value = 7

$chkUsers = New-Object System.Windows.Forms.CheckBox
$chkUsers.Text = "Incluir Temp de todos los usuarios (C:\Users\*\AppData\Local\Temp)"
$chkUsers.AutoSize = $true
$chkUsers.Location = '15,85'

$chkAgg = New-Object System.Windows.Forms.CheckBox
$chkAgg.Text = "Modo agresivo: limpiar Windows Update y Delivery Optimization"
$chkAgg.AutoSize = $true
$chkAgg.Location = '15,115'

$chkReset = New-Object System.Windows.Forms.CheckBox
$chkReset.Text = "DISM /ResetBase (no podrás desinstalar updates antiguos)"
$chkReset.AutoSize = $true
$chkReset.Location = '15,145'

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "Simulación (WhatIf) – no borra, solo registra acciones"
$chkWhatIf.AutoSize = $true
$chkWhatIf.Location = '15,175'
$chkWhatIf.Checked = $false

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "El log se guardará en C:\Logs\Cleanup-YYYYMMDD_HHMM.log"
$lblLog.AutoSize = $true
$lblLog.Location = '15,210'
$lblLog.ForeColor = [System.Drawing.Color]::Gray

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Ejecutar limpieza"
$btnRun.Location = '15,250'
$btnRun.Width = 150

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Location = '180,250'
$btnCancel.Width = 100

$btnWhatif = New-Object System.Windows.Forms.Button
$btnWhatif.Text = "Solo Simular"
$btnWhatif.Location = '290,250'
$btnWhatif.Width = 100

$form.Controls.AddRange(@($lblDays,$numDays,$chkUsers,$chkAgg,$chkReset,$chkWhatIf,$lblLog,$btnRun,$btnCancel,$btnWhatif))

$btnRun.Add_Click({
  $form.Enabled = $false
  Do-Cleanup -Days ([int]$numDays.Value) -IncludeUserTemps:$($chkUsers.Checked) -Aggressive:$($chkAgg.Checked) -ResetBase:$($chkReset.Checked) -WhatIf:$false
  [System.Windows.Forms.MessageBox]::Show("Limpieza completada.`nRevisa el log en C:\Logs.","Listo",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  $form.Close()
})

$btnWhatif.Add_Click({
  $form.Enabled = $false
  Do-Cleanup -Days ([int]$numDays.Value) -IncludeUserTemps:$($chkUsers.Checked) -Aggressive:$($chkAgg.Checked) -ResetBase:$($chkReset.Checked) -WhatIf:$true
  [System.Windows.Forms.MessageBox]::Show("Simulación completada (no se borró nada).`nRevisa el log en C:\Logs.","Simulación",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  $form.Close()
})

$btnCancel.Add_Click({ $form.Close() })

[void]$form.ShowDialog()
