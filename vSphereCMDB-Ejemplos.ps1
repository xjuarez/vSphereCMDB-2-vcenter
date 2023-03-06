############################################################################################
# Descripción:
# Secuencia de comandos de vSphere CMDB 4 de 5. Esto se conecta al servidor SQL/vCMDB especificado y luego le brinda algunos ejemplos de consultas/informes para ejecutar en sus datos.
############################################################################################
# Requisitos:
# - Set-executionpolicy unrestricted en la computadora que ejecuta el script
# - Acceso a una instancia de servidor SQL y vCMDB con permisos suficientes para consultar la base de datos ya creada
############################################################################################
# Configure las siguientes variables para conectarse a la base de datos SQL
############################################################################################
$SQLInstance = ".\SQLEXPRESS"
$SQLDatabase = "vSphereCMDBOCVS"
############################################################################################
# Importación de las credenciales de SQL
############################################################################################
$SQLCredentials = IMPORT-CLIXML ".\SQLCredentials.xml"
$SQLUsername = $SQLCredentials.UserName
$SQLPassword = $SQLCredentials.GetNetworkCredential().Password
############################################################################################
# Verificando si el módulo SqlServer ya está instalado, si no lo está instalando
############################################################################################
$SQLModuleCheck = Get-Module -ListAvailable SqlServer
if ($null -eq $SQLModuleCheck)
{
write-host "SqlServer Module No Funciona - Instalando"
# No instalado
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Instalando el modulo
Install-Module -Name SqlServer -Scope AllUsers -Confirm:$false -AllowClobber
}
############################################################################################
# Importación del módulo SqlServer
############################################################################################
Import-Module SqlServer
############################################################################################
# Consultar todas las tablas y asignarlas a variables para su uso posterior
############################################################################################
# VM table 
$VMsTableQuery = "USE $SQLDatabase
SELECT * FROM VMs"
$VMsTable = invoke-sqlcmd -query $VMsTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# VMDisks table 
$VMDisksTableQuery = "USE $SQLDatabase
SELECT * FROM VMDisks"
$VMDisksTable = invoke-sqlcmd -query $VMDisksTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# VMDiskUsage table 
$VMDiskUsageTableQuery = "USE $SQLDatabase
SELECT * FROM VMDisks"
$VMDiskUsageTable = invoke-sqlcmd -query $VMDiskUsageTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# VMNICs table 
$VMNICsTableQuery = "USE $SQLDatabase
SELECT * FROM VMNICs"
$VMNICsTable = invoke-sqlcmd -query $VMNICsTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Datastores table 
$DatastoresTableQuery = "USE $SQLDatabase
SELECT * FROM VMNICs"
$DatastoresTableQuery = invoke-sqlcmd -query $DatastoresTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# PortGroups table 
$PortGroupsTableQuery = "USE $SQLDatabase
SELECT * FROM PortGroups"
$PortGroupsTable = invoke-sqlcmd -query $PortGroupsTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Hosts table 
$HostsTableQuery = "USE $SQLDatabase
SELECT * FROM Hosts"
$HostsTable = invoke-sqlcmd -query $HostsTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Clusters table 
$ClustersTableQuery = "USE $SQLDatabase
SELECT * FROM Clusters"
$ClustersTable = invoke-sqlcmd -query $ClustersTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Datacenters table 
$DatacentersTableQuery = "USE $SQLDatabase
SELECT * FROM Datacenters"
$DatacentersTable = invoke-sqlcmd -query $DatacentersTableQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Consultas de ejemplo de la tabla de VM
############################################################################################
# Mostrar todas las configuraciones de una VM
$VMHistory = $VMsTable | Where-Object {$_.Name -eq "SQLServer-VM01"}
$VMHistory | Sort-Object LastUpdated | Out-GridView -Title "VM History"
# Enumere todas las fechas únicas en la tabla de VM de las que tomar una muestra
$VMDatesAvailable = $VMsTable | Select-Object LastUpdated -Unique
# Tomando la fecha más antigua disponible y mostrando todas las configuraciones de VM
$VMOldestDateSelected = $VMDatesAvailable | Sort-Object LastUpdated | Select-Object -ExpandProperty LastUpdated -First 1
$VMsTable | Where-Object {$_.LastUpdated -eq $VMOldestDateSelected} | Out-GridView -Title "VM Point In Time Config"
# Tomar los datos más recientes disponibles y mostrar el tamaño total de la máquina virtual aprovisionada y utilizada (útil para el dimensionamiento de Rubrik)
$VMNewestDateSelected = $VMDatesAvailable | Sort-Object LastUpdated | Select-Object -ExpandProperty LastUpdated -Last 1
$VMProvisionedSpaceGB = $VMsTable | Where-Object {$_.LastUpdated -eq $VMNewestDateSelected} | Select-Object -ExpandProperty ProvisionedSpaceGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
write-host "Total VM ProvisionedSpace (GB): $VMProvisionedSpaceGB"
$VMUsedSpaceGB = $VMsTable | Where-Object {$_.LastUpdated -eq $VMNewestDateSelected} | Select-Object -ExpandProperty UsedSpaceGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
write-host "Total VM UsedSpace (GB): $VMUsedSpaceGB"
# Tomando los datos más recientes y más antiguos disponibles y luego calculando el crecimiento durante el período (¡también útil para el dimensionamiento de Rubrik!)
$VMOldestUsedSpaceGB = $VMsTable | Where-Object {$_.LastUpdated -eq $VMOldestDateSelected} | Select-Object -ExpandProperty UsedSpaceGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$VMNewestUsedSpaceGB = $VMsTable | Where-Object {$_.LastUpdated -eq $VMNewestDateSelected} | Select-Object -ExpandProperty UsedSpaceGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Muestra de tiempo de cálculo en días
$TimeSpan = New-Timespan -Start $VMOldestDateSelected –End $VMNewestDateSelected | Select-Object -ExpandProperty TotalDays 
# Cálculo del porcentaje de crecimiento
$Diff = $VMNewestUsedSpaceGB - $VMOldestUsedSpaceGB
$PercentDiff = ($Diff / $VMOldestUsedSpaceGB) * 100
write-host "Time Sample in Days: $TimeSpan
Total VM UsedSpace Growth (%): $PercentDiff"
############################################################################################
# Consultas de ejemplo de la tabla VMDisks
############################################################################################
# Mostrar todas las configuraciones de VMDisk para una VM
$VMDiskConfigHistory = $VMDisksTable | Where-Object {$_.Parent -eq "HCHLvCenter"}
$VMDiskConfigHistory | Sort-Object LastUpdated | Out-GridView -Title "VMDisk Config History"
# Mostrar todas las configuraciones para un VMDK
$VMDiskConfigHistory = $VMDisksTable | Where-Object {($_.Parent -eq "HCHLvCenter") -and ($_.Name -eq "Hard disk 1")}
$VMDiskConfigHistory | Sort-Object LastUpdated | Out-GridView -Title "VMDisk Config History"
############################################################################################
# Consultas de ejemplo de la tabla VMNIC
############################################################################################
# Mostrar todas las configuraciones de VMNIC para una VM
$VMNICConfigHistory = $VMNICsTable | Where-Object {$_.Parent -eq "DC1vCenter"}
$VMNICConfigHistory | Sort-Object LastUpdated | Out-GridView -Title "VMNIC Config History"
# Mostrar todas las configuraciones para una VMNIC
$VMNICConfigHistory = $VMNICsTable | Where-Object {($_.Parent -eq "DC1vCenter") -and ($_.Name -eq "Network adapter 1")}
$VMNICConfigHistory | Sort-Object LastUpdated | Out-GridView -Title "VMNIC Config History"
############################################################################################
# Consultas de ejemplo de la tabla PortGroupsTable
############################################################################################
# Mostrar todas las configuraciones para un grupo de puertos en un host
$PortGroupHistory = $PortGroupsTable | Where-Object {($_.Name -eq "VM Network") -and ($_.VMHostId -eq "HostSystem-host-74")}
$PortGroupHistory | Sort-Object LastUpdated | Out-GridView -Title "Host Port Group History"
############################################################################################
# Consultas de ejemplo de la tabla Hosts
############################################################################################
# Mostrar todas las configuraciones de un Host
$HostHistory = $HostsTable | Where-Object {$_.Name -eq "192.168.0.13"}
$HostHistory | Sort-Object LastUpdated | Out-GridView -Title "Host History"
# Enumere todas las fechas únicas en la tabla Host de las que tomar una muestra
$HostDatesAvailable = $HostsTable | Select-Object LastUpdated -Unique
# Tomando la fecha más antigua disponible y mostrando todas las configuraciones de Host
$HostDateSelected = $HostDatesAvailable | Sort-Object LastUpdated | Select-Object -ExpandProperty LastUpdated -First 1
$HostsTable | Where-Object {$_.LastUpdated -eq $HostDateSelected} | Out-GridView -Title "Host Point In Time Config"
############################################################################################
# Consultas de ejemplo de la tabla Clusters
############################################################################################
# Mostrar todas las configuraciones de un Cluster
$ClusterHistory = $ClustersTable | Where-Object {$_.Name -eq "ProdCluster1"}
$ClusterHistory | Sort-Object LastUpdated | Out-GridView -Title "Cluster History"
# Enumere todas las fechas únicas en la tabla de conglomerados de las que tomar una muestra
$ClusterDatesAvailable = $ClustersTable | Select-Object LastUpdated -Unique
# Tomando la fecha más antigua disponible y mostrando todas las configuraciones de Host
$ClusterDateSelected = $ClusterDatesAvailable | Sort-Object LastUpdated | Select-Object -ExpandProperty LastUpdated -First 1
$ClustersTable | Where-Object {$_.LastUpdated -eq $ClusterDateSelected} | Out-GridView -Title "Cluster Point In Time Config"
############################################################################################
# Consultas de ejemplo de la tabla Datacenters
############################################################################################
# Mostrar todas las estadísticas de un centro de datos
$DatacenterHistory = $DatacentersTable | Where-Object {$_.Name -eq "Datacenter1"}
$DatacenterHistory | Sort-Object LastUpdated | Out-GridView -Title "Datacenter History"
# Enumere todas las fechas únicas en la tabla del centro de datos de las que tomar una muestra
$DatacenterDatesAvailable = $DatacentersTable | Select-Object LastUpdated -Unique
# Tomando la fecha más antigua disponible y mostrando todas las estadísticas del centro de datos
$DatacenterDateSelected = $DatacenterDatesAvailable | Sort-Object LastUpdated | Select-Object -ExpandProperty LastUpdated -First 1
$DatacentersTable | Where-Object {$_.LastUpdated -eq $DatacenterDateSelected} | Out-GridView -Title "Datacenter Point In Time Config"
############################################################################################
# Fin del script
############################################################################################