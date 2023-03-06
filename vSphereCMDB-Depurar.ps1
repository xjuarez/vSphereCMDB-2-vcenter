############################################################################################
# Descripción:
# Secuencia de comandos de vSphere CMDB 5 de 5. Esta secuencia de comandos elimina todos los registros anteriores al $SQLDataMaxHistoryInDays configurado en la línea 31. Úselo con la frecuencia deseada o no.
############################################################################################
# Requisitos:
# - Set-executionpolicy unrestricted en la computadora que ejecuta el script
# - Acceso a una instancia de servidor SQL y vCMDB con permisos suficientes para consultar la base de datos ya creada
############################################################################################
# Configure las siguientes variables para conectarse a la base de datos SQL
############################################################################################
# Servidor SQL, base de datos y autenticación
$SQLInstance = ".\SQLEXPRESS"
$SQLDatabase = "vSphereCMDB"
# Historial máximo de retención de registros, después de x días configurados (cualquier máximo, o simplemente no ejecute este script), los registros se eliminan de la base de datos
$SQLDataMaxHistoryInDays = "0" 
############################################################################################
# No hay nada que cambiar debajo de esta línea, se proporcionan comentarios si necesita/quiere cambiar algo
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
Install-Module -Name SqlServer –Scope AllUsers -Confirm:$false -AllowClobber
}
############################################################################################
# mportación del módulo SqlServer
############################################################################################
Import-Module SqlServer
############################################################################################
# Configuración de las fechas actuales (para usar en cada fila de SQL insertada para podar el historial)
############################################################################################
$LastUpdated = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
# Restar SQLDataMaxHistoryInDays de la hora actual para eliminar los datos anteriores a esta fecha
$MaxHistoryDate = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date).AddDays(-$SQLDataMaxHistoryInDays)
############################################################################################
# Eliminación de la tabla SQL de máquinas virtuales
############################################################################################
# Creando la consulta SELECT para encontrar registros para eliminar 
$SQLVMPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.VMs"
# Ejecutando SELECT query
$VMPruneOutput = $null
$VMPruneOutput = invoke-sqlcmd -query $SQLVMPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMRecordsToPrune = $VMPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMRecordsToPrune)
{
ForEach($VMRecord in $VMRecordsToPrune)
{
$VMRecordID = $VMRecord.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMRecord = "USE $SQLDatabase
DELETE FROM op.VMs
WHERE RecordID='$VMRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de VMDisks
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLVMDiskPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.VMDisks"
# Ejecutando SELECT query
$VMDiskPruneOutput = $null
$VMDiskPruneOutput = invoke-sqlcmd -query $SQLVMDiskPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMDiskRecordsToPrune = $VMDiskPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMDiskRecordsToPrune)
{
ForEach($VMDisk in $VMDiskRecordsToPrune)
{
$VMDiskRecordID = $VMDisk.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMDiskRecord = "USE $SQLDatabase
DELETE FROM op.VMDisks
WHERE RecordID='$VMDiskRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMDiskRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de VMNIC
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLVMNICsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.VMNICs"
# Ejecutando SELECT query
$VMNICPruneOutput = $null
$VMNICPruneOutput = invoke-sqlcmd -query $SQLVMNICsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMNICRecordsToPrune = $VMNICPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMNICRecordsToPrune)
{
ForEach($VMNIC in $VMNICRecordsToPrune)
{
$VMNICRecordID = $VMNIC.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMNICRecord = "USE $SQLDatabase
DELETE FROM op.VMNICs
WHERE RecordID='$VMNICRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMNICRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de tablas SQL de almacenes de datos
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar  
$SQLDatastoresPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.Datastores"
# Ejecutando SELECT query
$DatastorePruneOutput = $null
$DatastorePruneOutput = invoke-sqlcmd -query $SQLDatastoresPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$DatastoreRecordsToPrune = $DatastorePruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $DatastoreRecordsToPrune)
{
ForEach($Datastore in $DatastoreRecordsToPrune)
{
$DatstoreRecordID = $Datastore.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteDatstoreRecord = "USE $SQLDatabase
DELETE FROM op.Datastores
WHERE RecordID='$DatstoreRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteDatstoreRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de grupos de puertos
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLPortGroupsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.PortGroups"
# Ejecutando SELECT query
$PortGroupPruneOutput = $null
$PortGroupPruneOutput = invoke-sqlcmd -query $SQLPortGroupsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$PortGroupRecordsToPrune = $PortGroupPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $PortGroupRecordsToPrune)
{
ForEach($PortGroup in $PortGroupRecordsToPrune)
{
$PortGroupRecordID = $PortGroup.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeletePortGroupRecord = "USE $SQLDatabase
DELETE FROM op.PortGroups
WHERE RecordID='$PortGroupRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeletePortGroupRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de hosts
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLHostsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.Hosts"
# Ejecutando SELECT query
$HostPruneOutput = $null
$HostPruneOutput = invoke-sqlcmd -query $SQLHostsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$HostRecordsToPrune = $HostPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $HostRecordsToPrune)
{
ForEach($ESXiHost in $HostRecordsToPrune)
{
$HostRecordID = $ESXiHost.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteHostRecord = "USE $SQLDatabase
DELETE FROM op.Hosts
WHERE RecordID='$HostRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteHostRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de clústeres
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLClustersPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.Clusters"
# Ejecutando SELECT query
$ClusterPruneOutput = $null
$ClusterPruneOutput = invoke-sqlcmd -query $SQLClustersPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$ClusterRecordsToPrune = $ClusterPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $ClusterRecordsToPrune)
{
ForEach($Cluster in $ClusterRecordsToPrune)
{
$ClusterRecordID = $Cluster.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteClusterRecord = "USE $SQLDatabase
DELETE FROM op.Clusters
WHERE RecordID='$ClusterRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteClusterRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de los Datacenters
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLDatacentersPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM op.Datacenters"
# Ejecutando SELECT query
$DatacenterPruneOutput = $null
$DatacenterPruneOutput = invoke-sqlcmd -query $SQLDatacentersPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$DatacenterRecordsToPrune = $DatacenterPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $DatacenterRecordsToPrune)
{
ForEach($Datacenter in $CDatacenterRecordsToPrune)
{
$DatacenterRecordID = $Datacenter.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteDatacenterRecord = "USE $SQLDatabase
DELETE FROM op.Datacenters
WHERE RecordID='$DatacenterRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteDatacenterRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# OCVS
############################################################################################
# Eliminación de la tabla SQL de máquinas virtuales OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros para eliminar 
$SQLVMPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.VMs"
# Ejecutando SELECT query
$VMPruneOutput = $null
$VMPruneOutput = invoke-sqlcmd -query $SQLVMPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMRecordsToPrune = $VMPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMRecordsToPrune)
{
ForEach($VMRecord in $VMRecordsToPrune)
{
$VMRecordID = $VMRecord.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMRecord = "USE $SQLDatabase
DELETE FROM ocvs.VMs
WHERE RecordID='$VMRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de VMDisks OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLVMDiskPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.VMDisks"
# Ejecutando SELECT query
$VMDiskPruneOutput = $null
$VMDiskPruneOutput = invoke-sqlcmd -query $SQLVMDiskPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMDiskRecordsToPrune = $VMDiskPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMDiskRecordsToPrune)
{
ForEach($VMDisk in $VMDiskRecordsToPrune)
{
$VMDiskRecordID = $VMDisk.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMDiskRecord = "USE $SQLDatabase
DELETE FROM ocvs.VMDisks
WHERE RecordID='$VMDiskRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMDiskRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de VMNIC OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLVMNICsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.VMNICs"
# Ejecutando SELECT query
$VMNICPruneOutput = $null
$VMNICPruneOutput = invoke-sqlcmd -query $SQLVMNICsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$VMNICRecordsToPrune = $VMNICPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $VMNICRecordsToPrune)
{
ForEach($VMNIC in $VMNICRecordsToPrune)
{
$VMNICRecordID = $VMNIC.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteVMNICRecord = "USE $SQLDatabase
DELETE FROM ocvs.VMNICs
WHERE RecordID='$VMNICRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteVMNICRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de tablas SQL de almacenes de datos OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar  
$SQLDatastoresPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.Datastores"
# Ejecutando SELECT query
$DatastorePruneOutput = $null
$DatastorePruneOutput = invoke-sqlcmd -query $SQLDatastoresPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$DatastoreRecordsToPrune = $DatastorePruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $DatastoreRecordsToPrune)
{
ForEach($Datastore in $DatastoreRecordsToPrune)
{
$DatstoreRecordID = $Datastore.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteDatstoreRecord = "USE $SQLDatabase
DELETE FROM ocvs.Datastores
WHERE RecordID='$DatstoreRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteDatstoreRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de grupos de puertos OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLPortGroupsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.PortGroups"
# Ejecutando SELECT query
$PortGroupPruneOutput = $null
$PortGroupPruneOutput = invoke-sqlcmd -query $SQLPortGroupsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$PortGroupRecordsToPrune = $PortGroupPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $PortGroupRecordsToPrune)
{
ForEach($PortGroup in $PortGroupRecordsToPrune)
{
$PortGroupRecordID = $PortGroup.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeletePortGroupRecord = "USE $SQLDatabase
DELETE FROM ocvs.PortGroups
WHERE RecordID='$PortGroupRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeletePortGroupRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de hosts OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLHostsPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.Hosts"
# Ejecutando SELECT query
$HostPruneOutput = $null
$HostPruneOutput = invoke-sqlcmd -query $SQLHostsPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$HostRecordsToPrune = $HostPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $HostRecordsToPrune)
{
ForEach($ESXiHost in $HostRecordsToPrune)
{
$HostRecordID = $ESXiHost.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteHostRecord = "USE $SQLDatabase
DELETE FROM ocvs.Hosts
WHERE RecordID='$HostRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteHostRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de clústeres OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar
$SQLClustersPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.Clusters"
# Ejecutando SELECT query
$ClusterPruneOutput = $null
$ClusterPruneOutput = invoke-sqlcmd -query $SQLClustersPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$ClusterRecordsToPrune = $ClusterPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $ClusterRecordsToPrune)
{
ForEach($Cluster in $ClusterRecordsToPrune)
{
$ClusterRecordID = $Cluster.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteClusterRecord = "USE $SQLDatabase
DELETE FROM ocvs.Clusters
WHERE RecordID='$ClusterRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteClusterRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Eliminación de la tabla SQL de los Datacenters OCVS
############################################################################################
# Creando la consulta SELECT para encontrar registros eliminar 
$SQLDatacentersPruneQuery = "USE $SQLDatabase
SELECT RecordID, LastUpdated FROM ocvs.Datacenters"
# Ejecutando SELECT query
$DatacenterPruneOutput = $null
$DatacenterPruneOutput = invoke-sqlcmd -query $SQLDatacentersPruneQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Selección de registros para eliminar en función de los más antiguos que MaxHistoryDate
$DatacenterRecordsToPrune = $DatacenterPruneOutput | Where-Object { $_.LastUpdated -lt $MaxHistoryDate}
# Realizar DELETE para cada registro aplicable, si el valor no es NULL (se encontraron registros coincidentes fuera del rango máximo de historial)
If ($null -ne $DatacenterRecordsToPrune)
{
ForEach($Datacenter in $CDatacenterRecordsToPrune)
{
$DatacenterRecordID = $Datacenter.RecordID
# Creando la consulta DELETE usando las variables definidas
$SQLDeleteDatacenterRecord = "USE $SQLDatabase
DELETE FROM ocvs.Datacenters
WHERE RecordID='$DatacenterRecordID';"
# Ejecutando DELETE query
invoke-sqlcmd -query $SQLDeleteDatacenterRecord -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
}
############################################################################################
# Fin del script
############################################################################################