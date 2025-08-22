Git & VS Code – Chuleta rápida (Álvaro)
0) Configuración inicial (una sola vez por equipo)
# Identidad
git config --global user.name "Álvaro Nieto"
git config --global user.email "alvaronieto.1992@outlook.com"

# VS Code como editor para mensajes de commit
git config --global core.editor "code --wait"

# (Opcional) Comportamiento de fin de línea estándar
git config --global core.autocrlf true   # Windows: checkout CRLF, commit LF

SSH con GitHub (si cambias de equipo)
# Generar clave
ssh-keygen -t ed25519 -C "tu_email@dominio.com"

# Arrancar y habilitar agente
Start-Service ssh-agent
Set-Service -Name ssh-agent -StartupType Automatic
ssh-add $env:USERPROFILE\.ssh\id_ed25519

# Copiar clave pública y añadirla en GitHub > Settings > SSH and GPG keys
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub

# Probar
ssh -T git@github.com

1) Clonar un repositorio existente
cd %USERPROFILE%\Documents
git clone git@github.com:alvaro1929/<NOMBRE_REPO>.git
cd <NOMBRE_REPO>
code .   # abrir en VS Code

2) Flujo diario (cambios rápidos)
git status                       # ver qué cambió
git add .                        # preparar TODO (o escoge archivos específicos)
git commit -m "feat: mensaje claro del cambio"
git pull --rebase origin main    # traer últimos cambios sin merge feo
git push                         # subir a GitHub


💡 En VS Code: panel “Control de código fuente”
– Marca solo los archivos que quieras (Stage) → escribe mensaje → ✓ Commit → … → Push.
– … → Pull (Rebase) para traer cambios antes de empujar.

3) Subir solo archivos concretos (evitar “subir basura”)
git status
git add Scripts/AD/New-BulkUsers.ps1        # añade solo ese
git add -p                                  # seleccionar trozos (hunks) interactivo
git commit -m "feat(ad): alta masiva de usuarios"
git pull --rebase origin main
git push


Revertir si añadiste algo por error:

git restore --staged ruta/del/archivo

4) Ramas por feature (recomendado incluso trabajando solo)
# Crear y cambiar a una rama nueva
git checkout -b feat/usuarios-bulk

# Trabaja, añade y commitea
git add Scripts/AD/New-BulkUsers.ps1
git commit -m "feat(ad): script de alta masiva"

# Sincroniza
git pull --rebase origin feat/usuarios-bulk
git push -u origin feat/usuarios-bulk


Luego, en GitHub, crea un Pull Request hacia main.
Opcional: Protege main en Settings → Branches → Branch protection rules (requerir PRs / rebase al día).

5) Resolver conflictos (paso a paso)

git pull --rebase origin TU-RAMA

Git marcará archivos en conflicto (<<<<<<<, =======, >>>>>>>).

Edita y deja la versión correcta.

Marca como resuelto:

git add archivo/conflictivo.ps1
git rebase --continue


Empuja:

git push --force-with-lease


En VS Code hay vista de Comparación de conflictos con botones “Aceptar ambos cambios”.

6) Mantener limpio el repo

.gitignore recomendado (ejemplo):

logs/
*.log
*.Transcript.txt
.vscode/
Config/*.json
!Config/examples/*.template.json
*.pfx
*.key
*.pem


Carpetas vacías: añade un .gitkeep para versionarlas:

New-Item Scripts\AD\.gitkeep -ItemType File

7) Guardar trabajo temporal sin commitear (stash)
git stash push -m "trabajo a medias"
git pull --rebase
git stash pop

8) Corregir el último commit (mensaje o archivos)
# Añade lo que faltó
git add ruta/que/falto
git commit --amend -m "mensaje corregido"
git push --force-with-lease

9) Cambiar remoto a SSH (si clonaste por HTTPS)
git remote -v
git remote set-url origin git@github.com:alvaro1929/<NOMBRE_REPO>.git

10) Ver historial y diferencias
git log --oneline --graph --decorate --all
git show HEAD
git diff                          # cambios no staged
git diff --staged                 # cambios staged

11) Etiquetar versiones (tags)
git tag v0.1.0
git push origin v0.1.0

12) Estructura sugerida del repo (scripts)
Scripts/
  AD/
  Azure/
  Hyper-V/
  Proxmox/
  Networking/
Modules/
Config/
  examples/
Tests/
README.md
GIT-CHEATSHEET.md

13) Atajos útiles en VS Code

Terminal integrado: Ctrl + ñ

Buscar comando: Ctrl + Shift + P (escribe “Git: …”)

Commit rápido: Panel de Git → escribe mensaje → ✓

Pull (Rebase): Panel de Git → … → Pull (Rebase)

Comparar cambios: clic en un archivo modificado → “Abrir cambios”

14) Mensajes de commit – formato sugerido
feat(ad): nueva alta masiva de usuarios
fix(azure): corrige parám. en deploy de VM
chore: estructura inicial del repo
docs: actualiza README


Tip final: antes de push en main, haz siempre git pull --rebase origin main.
Te evita merges innecesarios y mantiene el historial limpio.