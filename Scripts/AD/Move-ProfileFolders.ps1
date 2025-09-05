## Migra las carpetas especiales de usuario (Desktop, Documents, Downloads,
# Music, Pictures, Videos, Contacts, Favorites, Links, Saved Games, Searches) 
#desde un path al perfil local, actualiza registro y KnownFolders, mueve el contenido 
#con el motor de Explorer, preserva iconos y prepara un RunOnce para finalizar al próximo inicio de sesión del usuario.
# El script hay que ejecutarlo como admninistrador y meterle unos parametros:
#powershell -ExecutionPolicy Bypass -File "C:\Users\bgtec\Desktop\test.ps1" -SourceRoot "\\NAS\Users\Gail Fitzgerald" -DestProfile "C:\Users\gfitzgerald"


# Uso del script:
# powershell -ExecutionPolicy Bypass -File "C:\Users\<tu_usuario>\Desktop\Migrate-UserFolders.ps1" `
#   -SourceRoot "\\NAS\Users\<Nombre en NAS>" `
#   -DestProfile "C:\Users\<NombrePerfilLocal>"
#
# Ejemplo:
# powershell -ExecutionPolicy Bypass -File "C:\Users\bgtec\Desktop\Migrate-UserFolders.ps1" `
#   -SourceRoot "\\NAS\Users\Nombre Apellido" `
#   -DestProfile "C:\Users\napellido"



param(
  [Parameter(Mandatory)] [string]$SourceRoot,    # \\NAS\Users\<CarpetaDelUsuario>  (o U:\usuario)
  [Parameter(Mandatory)] [string]$DestProfile    # C:\Users\<usuario>
)

# --- Carpetas a migrar ---
$Folders = @('Contacts','Desktop','Documents','Downloads','Favorites','Links','Music','Pictures','Saved Games','Searches','Videos')

# --- GUIDs KnownFolders (para el RunOnce en el logon del usuario) ---
$KF = @{
  Desktop      = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
  Documents    = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
  Downloads    = '{374DE290-123F-4565-9164-39C4925E467B}'
  Favorites    = '{1777F761-68AD-4D8A-87BD-30B759FA33DD}'
  Links        = '{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}'
  Music        = '{4BD8D571-6D19-48D3-BE97-422220080E43}'
  Pictures     = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
  Videos       = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
  Contacts     = '{56784854-C6CB-462B-8169-88E350ACB882}'
  Searches     = '{7D1D3A04-DEBB-4115-95CF-2F29DA2920DA}'
  'Saved Games'= '{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}'
}

# --- Nombres en HKU\User Shell Folders / Shell Folders ---
$Reg = @{
  Desktop='Desktop'; Documents='Personal'; Downloads='{374DE290-123F-4565-9164-39C4925E467B}'
  Favorites='Favorites'; Links='{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}'
  Music='My Music'; Pictures='My Pictures'; Videos='My Video'
  Contacts='{56784854-C6CB-462B-8169-88E350ACB882}'; Searches='{7D1D3A04-DEBB-4115-95CF-2F29DA2920DA}'
  'Saved Games'='{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}'
}

# --- Validaciones básicas ---
if (!(Test-Path -LiteralPath $DestProfile)) { throw "No existe el perfil destino: $DestProfile" }
$NtUser = Join-Path $DestProfile 'NTUSER.DAT'
$CanWriteHive = Test-Path -LiteralPath $NtUser

# --- Cargar hive HKU\TempKF (si existe NTUSER.DAT) ---
$HiveName = 'TempKF'
if ($CanWriteHive) {
  reg load "HKU\$HiveName" "$NtUser" | Out-Null
  $USF  = "Registry::HKEY_USERS\$HiveName\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
  $SF   = "Registry::HKEY_USERS\$HiveName\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
  $USFp = "Registry::HKEY_USERS\$HiveName\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\User Shell Folders"
  $SFp  = "Registry::HKEY_USERS\$HiveName\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Shell Folders"
}

# --- Mover con el motor de Explorer (igual que Location > Move…) ---
function Move-WithExplorer([string]$src,[string]$dst){
  if (!(Test-Path -LiteralPath $src)) { return }
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  $sh = New-Object -ComObject Shell.Application
  $flags = 0x0004 -bor 0x0010 -bor 0x0200   # SILENT + NOCONFIRMATION + NOCONFIRMMKDIR
  $sh.NameSpace($dst).MoveHere($sh.NameSpace($src).Items(), $flags)
}

# --- 1) Crear destino y PRIMER movimiento ---
foreach($f in $Folders){
  $dst = Join-Path $DestProfile $f
  $src = Join-Path $SourceRoot  $f
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  Move-WithExplorer $src $dst
  try { attrib +r +s $dst 2>$null } catch {}
  Write-Host ("Movido  : {0,-12} -> {1}" -f $f,$dst)
}

# --- 2) Escribir ubicaciones en el HIVE del usuario (si podemos) y limpiar Policies ---
if ($CanWriteHive) {
  New-Item -Path $USF -Force | Out-Null
  New-Item -Path $SF  -Force | Out-Null

  foreach($f in $Folders){
    $dst  = Join-Path $DestProfile $f
    $name = $Reg[$f]

    # User Shell Folders (REG_EXPAND_SZ -> %USERPROFILE%\Sub)
    Remove-ItemProperty -Path $USF -Name $name -ErrorAction SilentlyContinue
    New-ItemProperty -Path $USF -Name $name -PropertyType ExpandString -Value "%USERPROFILE%\$f" -Force | Out-Null

    # Shell Folders (REG_SZ -> ruta absoluta)
    if (Get-ItemProperty -Path $SF -Name $name -ErrorAction SilentlyContinue) {
      Set-ItemProperty -Path $SF -Name $name -Value $dst
    } else {
      New-ItemProperty -Path $SF -Name $name -PropertyType String -Value $dst -Force | Out-Null
    }

    # Limpiar Policies si existieran
    foreach($k in @($USFp,$SFp)){ if (Test-Path $k) { Remove-ItemProperty -Path $k -Name $name -ErrorAction SilentlyContinue } }
  }

  # --- 3) Dejar RunOnce para fijar con la API (al próximo logon del usuario) ---
  $Finalize = @"
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class KFFin {
  [DllImport("shell32.dll")] public static extern int SHSetKnownFolderPath(ref Guid rfid,uint flags,IntPtr token,string path);
}
'@
\$map = @{
  'Desktop'     = '$($KF.Desktop)'
  'Documents'   = '$($KF.Documents)'
  'Downloads'   = '$($KF.Downloads)'
  'Favorites'   = '$($KF.Favorites)'
  'Links'       = '$($KF.Links)'
  'Music'       = '$($KF.Music)'
  'Pictures'    = '$($KF.Pictures)'
  'Videos'      = '$($KF.Videos)'
  'Contacts'    = '$($KF.Contacts)'
  'Searches'    = '$($KF.Searches)'
  'Saved Games' = '$($KF.'Saved Games')'
}
foreach(\$k in \$map.Keys){
  \$g=[Guid]\$map[\$k]; \$p=Join-Path \$env:USERPROFILE \$k
  New-Item -ItemType Directory -Path \$p -Force | Out-Null
  [void][KFFin]::SHSetKnownFolderPath([ref]\$g,0,[IntPtr]::Zero,\$p)
  try{ attrib +r +s \$p 2>\$null }catch{}
}
"@
  $FinalizePath = Join-Path $DestProfile 'Finalize-KnownFolders.ps1'
  $Finalize | Set-Content -Encoding UTF8 $FinalizePath

  $RunOnce = "Registry::HKEY_USERS\$HiveName\Software\Microsoft\Windows\CurrentVersion\RunOnce"
  New-Item -Path $RunOnce -Force | Out-Null
  New-ItemProperty -Path $RunOnce -Name "FinalizeKnownFolders" -PropertyType String -Value "powershell -NoProfile -ExecutionPolicy Bypass -File `"$FinalizePath`"" -Force | Out-Null
}

# --- 4) SEGUNDO intento de movimiento (por si quedaron archivos en uso en el primer pase) ---
foreach($f in $Folders){
  $src = Join-Path $SourceRoot  $f
  $dst = Join-Path $DestProfile $f
  if (Test-Path -LiteralPath $src) { Move-WithExplorer $src $dst }
}

# --- 5) Informe de restos en origen ---
$left = @()
foreach($f in $Folders){
  $p = Join-Path $SourceRoot $f
  if (Test-Path $p){
    $items = Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($items.Count -gt 0){
      $left += [PSCustomObject]@{ Folder=$f; Remaining=$items.Count; Path=$p }
    }
  }
}

# --- Descargar hive si lo cargamos ---
if ($CanWriteHive) { reg unload "HKU\$HiveName" | Out-Null }

# --- Salida final ---
if ($left.Count -gt 0){
  Write-Host "`n⚠ Quedan elementos en el origen (probablemente abiertos o sin permisos). Reintenta más tarde:" -ForegroundColor Yellow
  $left | Format-Table -AutoSize
} else {
  Write-Host "`n✅ Todo movido a $DestProfile y ubicaciones preparadas. Se fijarán al próximo logon del usuario." -ForegroundColor Green
}
