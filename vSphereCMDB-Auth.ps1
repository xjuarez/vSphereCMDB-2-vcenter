############################################################################################
# Descripción:
# Secuencia de scripts vSphere CMDB 1 de 5. Esta secuencia de comandos establece las credenciales de SQL y vSphere para su uso en las otras 4 secuencias de comandos.
############################################################################################
# Requisitos:
# - Set-executionpolicy unrestricted en la computadora que ejecuta el script
# - Ejecute el script como administrador para permitir la instalación del nuevo módulo para todos los usuarios
# - Acceso a Internet para descargar los módulos SqlServer y PowerCLI si aún no están instalados
############################################################################################
# Solicita y guarda credenciales de SQL
Get-Credential -Message "Enter your SQL username & password" | EXPORT-CLIXML ".\SQLCredentials.xml"
# Solicita y guarda credenciales de vCenter OP
Get-Credential -Message "Enter your vCenter OP username & password" | EXPORT-CLIXML ".\vCenterCredentialsop.xml"
# Solicita y guarda credenciales de vCenter OCVS
Get-Credential -Message "Enter your vCenter OCVS username & password" | EXPORT-CLIXML ".\vCenterCredentialsocvs.xml"
############################################################################################
# Comprobando si el módulo SqlServer ya está instalado, si no lo instalara
############################################################################################
$SQLModuleCheck = Get-Module -ListAvailable SqlServer
if ($null -eq $SQLModuleCheck)
{
write-host "SqlServer Module Not Found - Installing"
# No instalado
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Instalando el modulo
Install-Module -Name SqlServer -Scope AllUsers -Confirm:$false -AllowClobber
}
$PowerCLIModuleCheck = Get-Module -ListAvailable VMware.PowerCLI
############################################################################################
# Comprobando si el módulo vMWare ya está instalado, si no lo instalara
############################################################################################
if ($null -eq $PowerCLIModuleCheck)
{
write-host "PowerCLI Module Not Found - Installing"
# No instalado
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Instalando el modulo
Install-Module -Name VMware.PowerCLI –Scope AllUsers -Confirm:$false
}
############################################################################################
# Fin del script
############################################################################################