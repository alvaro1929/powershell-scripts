# ===================== EDITA SOLO ESTA ZONA =====================
# NOMBRE EXACTO de la GPO a exportar (como aparece en GPMC)
$GpoName   = 'test'

# Dominio ORIGEN (ej. 'homelab.local'). Déjalo vacío '' si quieres usar el dominio actual.
$Domain    = 'homelab.local'

# Carpeta RAÍZ donde quieres que se guarde el backup
$DestRoot  = 'C:\Users\alvaro\Desktop\GPO'

# Opcionales: genera informe HTML y ZIP (True/False)
$CreateReport = $true
$CreateZip    = $true
# ===================== NO EDITES BAJO ESTA LÍNEA =====================

function Sanitize([string]$s){ return ($s -replace '[\\/:*?"<>|]','_') }

Import-Module GroupPolicy -ErrorAction Stop

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$safeName  = Sanitize $GpoName
$outDir    = Join-Path $DestRoot "$safeName-$timestamp"

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Backup de la GPO
if ([string]::IsNullOrWhiteSpace($Domain)) {
  Backup-GPO -Name $GpoName -Path $outDir -Comment "Export $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-Null
  if ($CreateReport) { Get-GPOReport -Name $GpoName -ReportType Html -Path (Join-Path $outDir "$safeName.html") }
} else {
  Backup-GPO -Name $GpoName -Domain $Domain -Path $outDir -Comment "Export from $Domain $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-Null
  if ($CreateReport) { Get-GPOReport -Name $GpoName -Domain $Domain -ReportType Html -Path (Join-Path $outDir "$safeName.html") }
}

# Comprobación rápida: GPMC lo ve como backup válido
Get-GPOBackup -Path $outDir | Sort-Object CreationTime -Descending | Format-Table DisplayName, Id, CreationTime

# ZIP opcional para transportarlo
if ($CreateZip) {
  $zipPath = Join-Path $DestRoot "$safeName-$timestamp.zip"
  Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force
  Write-Host "ZIP creado: $zipPath"
}

Write-Host "`nCarpeta para importar con 'Import Settings' (selecciona la carpeta PADRE):"
Write-Host $outDir -ForegroundColor Cyan