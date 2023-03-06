############################################################################################
# Descripción:
# Secuencia de comandos vSphere CMDB 3 de 5. Esta secuencia de comandos se conecta al servidor vCenter especificado (línea 29) e inserta los datos en su VCMDB. Asegúrese de que SQLInstance y SQLDatabase sean correctos.
############################################################################################
# Requisitos:
# - Establecer política de ejecución sin restricciones en la computadora que ejecuta el script
# - Acceso a una instancia de servidor SQL con permisos suficientes para insertar en la base de datos vCMDB creada
# - Acceso a un vCenter con permisos para leer todos los objetos consultados
############################################################################################
# Configure las siguientes variables para conectarse a la base de datos SQL y vCenter
############################################################################################
# vSphere server
$vCenterServerop = "192.168.161.202"
$vCenterServerocvs = "10.254.44.2"
# SQL server & database
$SQLInstance = ".\SQLEXPRESS"
$SQLDatabase = "vSphereCMDB"
############################################################################################
# No hay nada que cambiar debajo de esta línea, se proporcionan comentarios si necesita/quiere cambiar algo
############################################################################################
# Importación de las credenciales de SQL
############################################################################################
$SQLCredentials = IMPORT-CLIXML ".\SQLCredentials.xml"
$SQLUsername = $SQLCredentials.UserName
$SQLPassword = $SQLCredentials.GetNetworkCredential().Password
############################################################################################
# Importación de las credenciales de vCenter
############################################################################################
$vCenterCredentialsop = IMPORT-CLIXML ".\vCenterCredentialsop.xml"
$vCenterCredentialsocvs = IMPORT-CLIXML ".\vCenterCredentialsocvs.xml"
############################################################################################
# Comprobando si el módulo  PowerCLI ya está instalado, si no lo instalara
############################################################################################
$PowerCLIModuleCheck = Get-Module -ListAvailable VMware.PowerCLI
if ($null -eq $PowerCLIModuleCheck)
{
write-host "PowerCLI Module No Funciona - Instalando"
# No instalado
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Instalando el modulo
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Confirm:$false -AllowClobber
}
############################################################################################
# Importación del módulo PowerCLI
############################################################################################
Import-Module VMware.PowerCLI
############################################################################################
# Comprobando si el módulo SqlServer ya está instalado, si no lo instalara
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
# Conexión a vCenter OP
############################################################################################
Try 
{
connect-viserver -Server $vCenterServerop -Credential $vCenterCredentialsop
$vCenterAuthentication = "PASS"
}
Catch 
{
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
$vCenterAuthentication = "FAIL"
}
"----------------------------"
"Connecting vCenter:$vCenterServerop
Connection:$vCenterAuthentication"
############################################################################################
# Configuración de las fechas actuales (para usar en cada fila de SQL insertada)
############################################################################################
$LastUpdated = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
############################################################################################
# Inserción en la tabla SQL de máquinas virtuales
############################################################################################
# Mostrando acción, útil para solucionar problemas
"----------------------------"
"Ejecutando Get-VM | Select *"
# Para conocen el estato de las Tools visita = https://blogs.vmware.com/PowerCLI/2011/11/vm-tools-and-virtual-hardware-versions.html
New-VIProperty -Name ToolsVersion -ObjectType VirtualMachine -ValueFromExtensionProperty 'Config.tools.ToolsVersion' -Force 
New-VIProperty -Name ToolsVersionStatus -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsVersionStatus' -Force
$VMs = Get-VM | Select-Object *
$VMGuestInfo = Get-VM | Get-VMGuest | Select-Object *
# Insertar cada fila
ForEach ($VM in $VMs)
{
$VMID = $VM.Id
$Name = $VM.Name
$PowerState = $VM.PowerState
$Notes = $VM.Notes
$Guest = $VM.Guest
$NumCpu = $VM.NumCpu -as [int]
$CoresPerSocket = $VM.CoresPerSocket -as [int]
$MemoryGB = $VM.MemoryGB -as [int]
$VMHostId = $VM.VMHostId
$VMHost = $VM.VMHost
$VApp = $VM.VApp
$FolderId = $VM.FolderId
$Folder = $VM.Folder
$ResourcePoolId = $VM.ResourcePoolId
$ResourcePool = $VM.ResourcePool
$HARestartPriority = $VM.HARestartPriority
$HAIsolationResponse = $VM.HAIsolationResponse
$DrsAutomationLevel = $VM.DrsAutomationLevel
$VMSwapfilePolicy = $VM.VMSwapfilePolicy
$VMResourceConfiguration = $VM.VMResourceConfiguration
$Version = $VM.Version
$UsedSpaceGB = $VM.UsedSpaceGB -as [int]
$ProvisionedSpaceGB = $VM.ProvisionedSpaceGB -as [int]
$DatastoreIdList = $VM.DatastoreIdList
$ExtensionData = $VM.ExtensionData
$CustomFields = $VM.CustomFields
$Uid = $VM.Uid
$PersistentId = $VM.PersistentId
$ToolsVersion = $VM.ToolsVersion
$ToolsVersionStatus = $VM.ToolsVersionStatus
# Extraer campos de VMGuestInfo para consolidar en una sola tabla
$VMGuest = $VMGuestInfo | Where-Object {$_.Vmid -eq $VMID}
$OSFullName = $VMGuest.OSFullName
$IPAddress = $VMGuest.IPAddress
$State = $VMGuest.State
$Hostname = $VMGuest.HostName
$Nics = $VMGuest.Nics
$GuestId = $VMGuest.GuestId
$RuntimeGuestId = $VMGuest.RuntimeGuestId
$GuestFamily = $VMGuest.GuestFamily
# Salida de diagnóstico, se puede habilitar a continuación
# "SQL Insert for VM:$Name"
# Creando SQL INSERT
$SQLVMInsert = "USE $SQLDatabase
INSERT INTO op.VMs (LastUpdated, VMID, Name, PowerState, Notes, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHostId, VMHost, VApp, FolderId, 
Folder, ResourcePoolId, ResourcePool, HARestartPriority, HAIsolationResponse, DrsAutomationLevel, VMSwapfilePolicy, VMResourceConfiguration, 
Version, UsedSpaceGB, ProvisionedSpaceGB, DatastoreIdList, ExtensionData, CustomFields, Uid, PersistentId, OSFullName, 
IPAddress, State, Hostname, Nics, GuestID, RuntimeGuestId, ToolsVersion, ToolsVersionStatus, GuestFamily)
VALUES('$LastUpdated', '$VMID', '$Name', '$PowerState', '$Notes', '$Guest', '$NumCpu', '$CoresPerSocket', '$MemoryGB', '$VMHostId', '$VMHost', '$VApp', '$FolderId', 
'$Folder', '$ResourcePoolId', '$ResourcePool', '$HARestartPriority', '$HAIsolationResponse', '$DrsAutomationLevel', '$VMSwapfilePolicy', '$VMResourceConfiguration', 
'$Version', '$UsedSpaceGB', '$ProvisionedSpaceGB', '$DatastoreIdList', '$ExtensionData', '$CustomFields', '$Uid', '$PersistentId', '$OSFullName', 
'$IPAddress', '$State', '$Hostname', '$Nics', '$GuestId', '$RuntimeGuestId', '$ToolsVersion', '$ToolsVersionStatus', '$GuestFamily');"
# ejecutando el INSERT query
invoke-sqlcmd -query $SQLVMInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Fin de la acción por VM a continuación
}
# Fin de la acción por VM anterior
############################################################################################
# Inserción en la tabla SQL de VMDisks
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VM | Get-HardDisk | Select *"
# Ejecutando CMD
$VMHardDisks = Get-VM | Get-HardDisk | Select-Object *
# Insertar cada fila
ForEach ($VMHardDisk in $VMHardDisks)
{
$VMID = $VMHardDisk.ParentId
$Parent = $VMHardDisk.Parent
$DiskID = $VMHardDisk.Id
$Name = $VMHardDisk.Name
$Filename = $VMHardDisk.Filename
$CapacityGB = $VMHardDisk.CapacityGB -as [int]
$Persistence = $VMHardDisk.Persistence
$DiskType = $VMHardDisk.DiskType
$StorageFormat = $VMHardDisk.StorageFormat
# Creando SQL INSERT
$SQLDiskInsert = "USE $SQLDatabase
INSERT INTO op.VMDisks (LastUpdated, VMID, Parent, DiskID, Name, Filename, CapacityGB, Persistence, DiskType, StorageFormat)
VALUES('$LastUpdated', '$VMID', '$Parent', '$DiskID', '$Name', '$Filename', '$CapacityGB', '$Persistence', '$DiskType', '$StorageFormat');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDiskInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de VMDiskUsage
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-View -ViewType VirtualMachine | Where {-not $_.Config.Template}"
# Para intrucciones del uso consulta: http://www.virtu-al.net/2010/01/27/powercli-virtual-machine-disk-usage/
$AllVMsView = Get-View -ViewType VirtualMachine | Where-Object {-not $_.Config.Template}
$VMGuestDiskInfo = $AllVMsView | Select-Object *, @{N="NumDisks";E={@($_.Guest.Disk.Length)}} | Sort-Object -Descending NumDisks
# Poblando la matriz
ForEach ($VM in $VMGuestDiskInfo){
# Número de disco inicial en 0 para cada máquina virtual
 $DiskNum = 0
 Foreach ($Disk in $VM.Guest.Disk){
    $VMID = $VM.MoRef
    $Name = $VM.name
    $DiskNum = $DiskNum -as [INT]
    $DiskPath = $Disk.DiskPath
    $DiskCapacityGB = ([math]::Round($disk.Capacity/ 1GB)) -as [INT]
    $DiskFreeSpaceGB = ([math]::Round($disk.FreeSpace / 1GB)) -as [INT]
    $DiskCapacityMB = ([math]::Round($disk.Capacity/ 1MB)) -as [INT]
    $DiskFreeSpaceMB = ([math]::Round($disk.FreeSpace / 1MB)) -as [INT]
# Creando SQL INSERT
$SQLVMGuestDiskInsert = "USE $SQLDatabase
INSERT INTO op.VMDiskUsage (LastUpdated, VMID, Name, DiskNum, DiskPath, DiskCapacityGB, DiskFreeSpaceGB, DiskCapacityMB, DiskFreeSpaceMB)
VALUES('$LastUpdated', '$VMID', '$Name', '$DiskNum', '$DiskPath', '$DiskCapacityGB', '$DiskFreeSpaceGB', '$DiskCapacityMB', '$DiskFreeSpaceMB');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLVMGuestDiskInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Incrementando el número de disco
$DiskNum++
 } 
}
############################################################################################
# Inserción en la tabla SQL de VMNIC
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VM | Get-NetworkAdapter | Select *"
# Ejecutando CMD
$VMNetworkAdapters = Get-VM | Get-NetworkAdapter | Select-Object *
# Insertar cada fila
ForEach ($VMNetworkAdapter in $VMNetworkAdapters)
{
$VMID = $VMNetworkAdapter.ParentId
$Parent = $VMNetworkAdapter.Parent
$NICID = $VMNetworkAdapter.Id
$Name = $VMNetworkAdapter.Name
$MacAddress = $VMNetworkAdapter.MacAddress
$NetworkName = $VMNetworkAdapter.NetworkName
$ConnectionState = $VMNetworkAdapter.ConnectionState
$WakeOnLanEnabled = $VMNetworkAdapter.WakeOnLanEnabled
$Type = $VMNetworkAdapter.Type
# Creando SQL INSERT
$SQLNICInsert = "USE $SQLDatabase
INSERT INTO op.VMNICs (LastUpdated, VMID, Parent, NICID, Name, MacAddress, NetworkName, ConnectionState, WakeOnLanEnabled, Type)
VALUES('$LastUpdated', '$VMID', '$Parent', '$NICID', '$Name', '$MacAddress', '$NetworkName', '$ConnectionState', '$WakeOnLanEnabled', '$Type');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLNICInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de almacenes de datos
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-Datastore | Select *"
# Ejecutando CMD
$Datastores = Get-Datastore | Select-Object *
# Insertar cada fila
ForEach ($Datastore in $Datastores)
{
$DatastoreID = $Datastore.Id
$Name = $Datastore.Name
$CapacityGB = $Datastore.CapacityGB -as [int]
$FreeSpaceGB = $Datastore.FreeSpaceGB -as [int]
$State = $Datastore.State
$Type = $Datastore.Type
$FileSystemVersion = $Datastore.FileSystemVersion -as [int]
$Accessible = $Datastore.Accessible
$StorageIOControlEnabled = $Datastore.StorageIOControlEnabled
$CongestionThresholdMillisecond = $Datastore.CongestionThresholdMillisecond -as [int]
$ParentFolderId = $Datastore.ParentFolderId
$ParentFolder = $Datastore.ParentFolder
$DatacenterId = $Datastore.DatacenterId
$Datacenter = $Datastore.Datacenter
$Uid = $Datastore.Uid
# Creando SQL INSERT
$SQLDatastoreInsert = "USE $SQLDatabase
INSERT INTO op.Datastores (LastUpdated, DatastoreID, Name, CapacityGB, FreeSpaceGB, State, Type, FileSystemVersion, Accessible, 
StorageIOControlEnabled, CongestionThresholdMillisecond, ParentFolderId, ParentFolder, DatacenterId, Datacenter, Uid)
VALUES('$LastUpdated', '$DatastoreID', '$Name', '$CapacityGB', '$FreeSpaceGB', '$State', '$Type', '$FileSystemVersion', '$Accessible', 
'$StorageIOControlEnabled', '$CongestionThresholdMillisecond', '$ParentFolderId', '$ParentFolder', '$DatacenterId', '$Datacenter', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDatastoreInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL PortGroups
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VirtualPortGroup | Select *"
# Ejecutando CMD
$VirtualPortGroups = Get-VirtualPortGroup | Select-Object *
# Insertar cada fila
ForEach ($VirtualPortGroup in $VirtualPortGroups)
{
$VirtualSwitchId = $VirtualPortGroup.VirtualSwitchId
$Name = $VirtualPortGroup.Name
$VirtualSwitch = $VirtualPortGroup.VirtualSwitch
$VirtualSwitchName = $VirtualPortGroup.VirtualSwitchName
$PortGroupKey = $VirtualPortGroup.Key
$VLanId = $VirtualPortGroup.VLanId -as [int]
$VMHostId = $VirtualPortGroup.VMHostId
$VMHostUid = $VirtualPortGroup.VMHostUid
$Uid = $VirtualPortGroup.Uid
# Creando SQL INSERT
$SQLPortGroupInsert = "USE $SQLDatabase
INSERT INTO op.PortGroups (LastUpdated, VirtualSwitchId, Name, VirtualSwitch, VirtualSwitchName, PortGroupKey, VLanId, VMHostId, VMHostUid, Uid)
VALUES('$LastUpdated', '$VirtualSwitchId', '$Name', '$VirtualSwitch', '$VirtualSwitchName', '$PortGroupKey', '$VLanId', '$VMHostId', '$VMHostUid', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLPortGroupInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de hosts 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VMHost | Select Id,Name,State,ConnectionState,PowerState,NumCpu,CpuTotalMhz,CpuUsageMhz,MemoryTotalGB,MemoryUsageGB,ProcessorType,HyperthreadingActive,TimeZone,Version,Build"
"Por cada Host Ejecuta Get-Datastore/VirtualPortGroup/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutar CMD, no usar *, ya que encontré que esto no siempre responde en vSphere 6.5 en adelante
$Hosts = Get-VMHost | Select-Object Id,Name,State,ConnectionState,PowerState,NumCpu,CpuTotalMhz,CpuUsageMhz,MemoryTotalGB,MemoryUsageGB,ProcessorType,HyperthreadingActive,TimeZone,Version,Build
ForEach ($ESXiHost in $Hosts)
{
$HostID = $ESXiHost.Id
$Name = $ESXiHost.Name
$State = $ESXiHost.State
$ConnectionState = $ESXiHost.ConnectionState
$PowerState = $ESXiHost.PowerState
$NumCpu = $ESXiHost.NumCpu -as [int]
$CpuTotalMhz = $ESXiHost.CpuTotalMhz -as [int]
$CpuUsageMhz = $ESXiHost.CpuUsageMhz -as [int]
$MemoryTotalGB = $ESXiHost.MemoryTotalGB -as [int]
$MemoryUsageGB = $ESXiHost.MemoryUsageGB -as [int]
$ProcessorType = $ESXiHost.ProcessorType
$HyperthreadingActive = $ESXiHost.HyperthreadingActive
$TimeZone = $ESXiHost.TimeZone
$Version = $ESXiHost.Version -as [int]
$Build = $ESXiHost.Build -as [int]
$Parent = $ESXiHost.Parent
$IsStandalone = $ESXiHost.IsStandalone
$VMSwapfileDatastore = $ESXiHost.VMSwapfileDatastore
$StorageInfo = $ESXiHost.StorageInfo
$NetworkInfo = $ESXiHost.NetworkInfo -as [int]
$DiagnosticPartition = $ESXiHost.DiagnosticPartition
$FirewallDefaultPolicy = $ESXiHost.FirewallDefaultPolicy
$ApiVersion = $ESXiHost.ApiVersion -as [int]
$MaxEVCMode = $ESXiHost.MaxEVCMode
$Manufacturer = $ESXiHost.Manufacturer
$Model = $ESXiHost.Model
$DatastoreIdList = $ESXiHost.DatastoreIdList
$Uid = $ESXiHost.Uid
# Obteniendo totales por cada host
$HostDatastoreCount = Get-VMHost -Name $Name | Get-Datastore
$HostDatastores = $HostDatastoreCount.Count
$HostPortGroupCount = Get-VMHost -Name $Name | Get-VirtualPortGroup
$HostPortGroups = $HostPortGroupCount.Count
$HostVMCount = Get-VMHost -Name $Name | Get-VM
$HostVMs = $HostVMCount.Count
$HostVMDiskCount = Get-VMHost -Name $Name | Get-VM | Get-HardDisk
$HostVMDisks = $HostVMDiskCount.Count
$HostVMNICCount = Get-VMHost -Name $Name | Get-VM | Get-NetworkAdapter
$HostVMNICs = $HostVMNICCount.Count
# Creando SQL INSERT
$SQLHostInsert = "USE $SQLDatabase
INSERT INTO op.Hosts (LastUpdated, HostID, Name, VMs, VMDisks, VMNICs, Datastores, PortGroups, State, ConnectionState, PowerState, NumCpu, CpuTotalMhz, CpuUsageMhz, MemoryTotalGB, 
MemoryUsageGB, ProcessorType, HyperthreadingActive, TimeZone, Version, Build, Parent, IsStandalone, VMSwapfileDatastore, StorageInfo, NetworkInfo, 
DiagnosticPartition, FirewallDefaultPolicy, ApiVersion, MaxEVCMode, Manufacturer, Model, DatastoreIdList, Uid)
VALUES('$LastUpdated', '$HostID', '$Name', '$HostVMs', '$HostVMDisks', '$HostVMNICs', '$HostDatastores', '$HostPortGroups', '$State', '$ConnectionState', '$PowerState', '$NumCpu', '$CpuTotalMhz', '$CpuUsageMhz', '$MemoryTotalGB', 
'$MemoryUsageGB', '$ProcessorType', '$HyperthreadingActive', '$TimeZone', '$Version', '$Build', '$Parent', '$IsStandalone', '$VMSwapfileDatastore', '$StorageInfo', '$NetworkInfo',
'$DiagnosticPartition', '$FirewallDefaultPolicy', '$ApiVersion', '$MaxEVCMode', '$Manufacturer', '$Model', '$DatastoreIdList', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLHostInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de clústeres 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-Cluster | Select *"
"Para cada Cluster Running Get-VMHost/Datastore/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutando CMD
$Clusters = Get-Cluster | Select-Object *
# Insertar cada fila
ForEach ($Cluster in $Clusters)
{
$ClusterID = $Cluster.Id
$Name = $Cluster.Name
$DrsEnabled = $Cluster.DrsEnabled
$DrsMode = $Cluster.DrsMode
$DrsAutomationLevel = $Cluster.DrsAutomationLevel
$HAEnabled = $Cluster.HAEnabled
$HAAdmissionControlEnabled = $Cluster.HAAdmissionControlEnabled
$HAFailoverLevel = $Cluster.HAFailoverLevel
$HARestartPriority = $Cluster.HARestartPriority
$HAIsolationResponse = $Cluster.HAIsolationResponse
$HATotalSlots = $Cluster.HATotalSlots
$HAUsedSlots = $Cluster.HAUsedSlots
$HAAvailableSlots = $Cluster.HAAvailableSlots
$HASlotCpuMHz = $Cluster.HASlotCpuMHz
$HASlotMemoryGB = $Cluster.HASlotMemoryGB
$HASlotNumVCpus = $Cluster.HASlotNumVCpus
$ParentId = $Cluster.ParentId
$ParentFolder = $Cluster.ParentFolder
$VMSwapfilePolicy = $Cluster.VMSwapfilePolicy
$VsanEnabled = $Cluster.VsanEnabled
$VsanDiskClaimMode = $Cluster.VsanDiskClaimMode
$EVCMode = $Cluster.EVCMode
$CustomFields = $Cluster.CustomFields
$Uid = $Cluster.Uid
# Obteniendo totales de los cluster (hace que esta tabla sea útil)
$ClusterHostCount = Get-Cluster -Name $Name | Get-VMHost
$ClusterHosts = $ClusterHostCount.Count
$ClusterDatastoreCount = Get-Cluster -Name $Name | Get-Datastore
$ClusterDatastores = $ClusterDatastoreCount.Count
$ClusterVMCount = Get-Cluster -Name $Name | Get-VM
$ClusterVMs = $ClusterVMCount.Count
$ClusterVMDiskCount = Get-Cluster -Name $Name | Get-VM | Get-HardDisk
$ClusterVMDisks = $ClusterVMDiskCount.Count
$ClusterVMNICCount = Get-Cluster -Name $Name | Get-VM | Get-NetworkAdapter
$ClusterVMNICs = $ClusterVMNICCount.Count
# Creando SQL INSERT
$SQLClusterInsert = "USE $SQLDatabase
INSERT INTO op.Clusters (LastUpdated, ClusterID, Name, Hosts, VMs, VMDisks, VMNICs, Datastores, DrsEnabled, DrsMode, DrsAutomationLevel, HAEnabled, HAAdmissionControlEnabled, HAFailoverLevel, HARestartPriority, 
HAIsolationResponse, HATotalSlots, HAUsedSlots, HAAvailableSlots, HASlotCpuMHz, HASlotMemoryGB, HASlotNumVCpus, ParentId, ParentFolder, VMSwapfilePolicy, 
VsanEnabled, VsanDiskClaimMode, EVCMode, CustomFields, Uid)
VALUES('$LastUpdated', '$ClusterID', '$Name', '$ClusterHosts', '$ClusterVMs', '$ClusterVMDisks', '$ClusterVMNICs', '$ClusterDatastores', '$DrsEnabled', '$DrsMode', '$DrsAutomationLevel', '$HAEnabled', '$HAAdmissionControlEnabled', '$HAFailoverLevel', '$HARestartPriority', 
'$HAIsolationResponse', '$HATotalSlots', '$HAUsedSlots', '$HAAvailableSlots', '$HASlotCpuMHz', '$HASlotMemoryGB', '$HASlotNumVCpus', '$ParentId', '$ParentFolder', '$VMSwapfilePolicy',  
'$VsanEnabled', '$VsanDiskClaimMode', '$EVCMode', '$CustomFields', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLClusterInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de centros de datos 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecuta Get-Datacenter | Select *"
"Por cada DC Ejecuta Get-VMHost/Datastore/VirtualPortGroup/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutando CMD
$Datacenters = Get-Datacenter | Select-Object *
# Inserting each row
ForEach ($Datacenter in $Datacenters)
{
$DatacenterID = $Datacenter.Id
$Name = $Datacenter.Name
$CustomFields = $Datacenter.CustomFields
$ParentFolderId = $Datacenter.ParentFolderId
$ParentFolder = $Datacenter.ParentFolder
$Uid = $Datacenter.Uid
$DatastoreFolderId = $Datacenter.DatastoreFolderId
# Obteniendo totales de los datacenter (hace que esta tabla sea útil)
$DCClusterCount = Get-Datacenter -Name $Name | Get-Cluster
$DCClusters = $DCClusterCount.Count
$DCHostCount = Get-Datacenter -Name $Name | Get-VMHost
$DCHosts = $DCHostCount.Count
$DCDatastoreCount = Get-Datacenter -Name $Name | Get-Datastore
$DCDatastores = $DCDatastoreCount.Count
$DCPortGroupCount = Get-Datacenter -Name $Name | Get-VirtualPortGroup
$DCPortGroups = $DCPortGroupCount.Count
$DCVMCount = Get-Datacenter -Name $Name | Get-VM
$DCVMs = $DCVMCount.Count
$DCVMDiskCount = Get-Datacenter -Name $Name | Get-VM | Get-HardDisk
$DCVMDisks = $DCVMDiskCount.Count
$DCVMNICCount = Get-Datacenter -Name $Name | Get-VM | Get-NetworkAdapter
$DCVMNICs = $DCVMNICCount.Count
# Creando SQL INSERT
$SQLDatacenterInsert = "USE $SQLDatabase
INSERT INTO op.Datacenters (LastUpdated, DatacenterID, Name, Clusters, Hosts, VMs, VMDisks, VMNICs, Datastores, PortGroups, CustomFields, ParentFolderId, ParentFolder, Uid, DatastoreFolderId)
VALUES('$LastUpdated', '$DatacenterID', '$Name', '$DCClusters', '$DCHosts','$DCVMs', '$DCVMDisks', '$DCVMNICs', '$DCDatastores', '$DCPortGroups', '$CustomFields', '$ParentFolderId', '$ParentFolder', '$Uid', '$DatastoreFolderId');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDatacenterInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Desconectando del vCenter OP
############################################################################################
"----------------------------"
"Disconnecting vCenter:$vCenterServerop"
Disconnect-VIServer -Force -Confirm:$false
############################################################################################
# Conexión a vCenter OCVS
############################################################################################
Try 
{
connect-viserver -Server $vCenterServerocvs -Credential $vCenterCredentialsocvs
$vCenterAuthentication = "PASS"
}
Catch 
{
Write-Host $_.Exception.ToString()
$error[0] | Format-List -Force
$vCenterAuthentication = "FAIL"
}
"----------------------------"
"Connecting vCenter:$vCenterServerocvs
Connection:$vCenterAuthentication"
############################################################################################
# Configuración de las fechas actuales (para usar en cada fila de SQL insertada)
############################################################################################
$LastUpdated = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
############################################################################################
# Inserción en la tabla SQL de máquinas virtuales
############################################################################################
# Mostrando acción, útil para solucionar problemas
"----------------------------"
"Ejecutando Get-VM | Select *"
# Para conocen el estato de las Tools visita = https://blogs.vmware.com/PowerCLI/2011/11/vm-tools-and-virtual-hardware-versions.html
New-VIProperty -Name ToolsVersion -ObjectType VirtualMachine -ValueFromExtensionProperty 'Config.tools.ToolsVersion' -Force 
New-VIProperty -Name ToolsVersionStatus -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsVersionStatus' -Force
$VMs = Get-VM | Select-Object *
$VMGuestInfo = Get-VM | Get-VMGuest | Select-Object *
# Insertar cada fila
ForEach ($VM in $VMs)
{
$VMID = $VM.Id
$Name = $VM.Name
$PowerState = $VM.PowerState
$Notes = $VM.Notes
$Guest = $VM.Guest
$NumCpu = $VM.NumCpu -as [int]
$CoresPerSocket = $VM.CoresPerSocket -as [int]
$MemoryGB = $VM.MemoryGB -as [int]
$VMHostId = $VM.VMHostId
$VMHost = $VM.VMHost
$VApp = $VM.VApp
$FolderId = $VM.FolderId
$Folder = $VM.Folder
$ResourcePoolId = $VM.ResourcePoolId
$ResourcePool = $VM.ResourcePool
$HARestartPriority = $VM.HARestartPriority
$HAIsolationResponse = $VM.HAIsolationResponse
$DrsAutomationLevel = $VM.DrsAutomationLevel
$VMSwapfilePolicy = $VM.VMSwapfilePolicy
$VMResourceConfiguration = $VM.VMResourceConfiguration
$Version = $VM.Version
$UsedSpaceGB = $VM.UsedSpaceGB -as [int]
$ProvisionedSpaceGB = $VM.ProvisionedSpaceGB -as [int]
$DatastoreIdList = $VM.DatastoreIdList
$ExtensionData = $VM.ExtensionData
$CustomFields = $VM.CustomFields
$Uid = $VM.Uid
$PersistentId = $VM.PersistentId
$ToolsVersion = $VM.ToolsVersion
$ToolsVersionStatus = $VM.ToolsVersionStatus
# Extraer campos de VMGuestInfo para consolidar en una sola tabla
$VMGuest = $VMGuestInfo | Where-Object {$_.Vmid -eq $VMID}
$OSFullName = $VMGuest.OSFullName
$IPAddress = $VMGuest.IPAddress
$State = $VMGuest.State
$Hostname = $VMGuest.HostName
$Nics = $VMGuest.Nics
$GuestId = $VMGuest.GuestId
$RuntimeGuestId = $VMGuest.RuntimeGuestId
$GuestFamily = $VMGuest.GuestFamily
# Salida de diagnóstico, se puede habilitar a continuación
# "SQL Insert for VM:$Name"
# Creando SQL INSERT
$SQLVMInsert = "USE $SQLDatabase
INSERT INTO ocvs.VMs (LastUpdated, VMID, Name, PowerState, Notes, Guest, NumCpu, CoresPerSocket, MemoryGB, VMHostId, VMHost, VApp, FolderId, 
Folder, ResourcePoolId, ResourcePool, HARestartPriority, HAIsolationResponse, DrsAutomationLevel, VMSwapfilePolicy, VMResourceConfiguration, 
Version, UsedSpaceGB, ProvisionedSpaceGB, DatastoreIdList, ExtensionData, CustomFields, Uid, PersistentId, OSFullName, 
IPAddress, State, Hostname, Nics, GuestID, RuntimeGuestId, ToolsVersion, ToolsVersionStatus, GuestFamily)
VALUES('$LastUpdated', '$VMID', '$Name', '$PowerState', '$Notes', '$Guest', '$NumCpu', '$CoresPerSocket', '$MemoryGB', '$VMHostId', '$VMHost', '$VApp', '$FolderId', 
'$Folder', '$ResourcePoolId', '$ResourcePool', '$HARestartPriority', '$HAIsolationResponse', '$DrsAutomationLevel', '$VMSwapfilePolicy', '$VMResourceConfiguration', 
'$Version', '$UsedSpaceGB', '$ProvisionedSpaceGB', '$DatastoreIdList', '$ExtensionData', '$CustomFields', '$Uid', '$PersistentId', '$OSFullName', 
'$IPAddress', '$State', '$Hostname', '$Nics', '$GuestId', '$RuntimeGuestId', '$ToolsVersion', '$ToolsVersionStatus', '$GuestFamily');"
# ejecutando el INSERT query
invoke-sqlcmd -query $SQLVMInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Fin de la acción por VM a continuación
}
# Fin de la acción por VM anterior
############################################################################################
# Inserción en la tabla SQL de VMDisks
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VM | Get-HardDisk | Select *"
# Ejecutando CMD
$VMHardDisks = Get-VM | Get-HardDisk | Select-Object *
# Insertar cada fila
ForEach ($VMHardDisk in $VMHardDisks)
{
$VMID = $VMHardDisk.ParentId
$Parent = $VMHardDisk.Parent
$DiskID = $VMHardDisk.Id
$Name = $VMHardDisk.Name
$Filename = $VMHardDisk.Filename
$CapacityGB = $VMHardDisk.CapacityGB -as [int]
$Persistence = $VMHardDisk.Persistence
$DiskType = $VMHardDisk.DiskType
$StorageFormat = $VMHardDisk.StorageFormat
# Creando SQL INSERT
$SQLDiskInsert = "USE $SQLDatabase
INSERT INTO ocvs.VMDisks (LastUpdated, VMID, Parent, DiskID, Name, Filename, CapacityGB, Persistence, DiskType, StorageFormat)
VALUES('$LastUpdated', '$VMID', '$Parent', '$DiskID', '$Name', '$Filename', '$CapacityGB', '$Persistence', '$DiskType', '$StorageFormat');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDiskInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de VMDiskUsage
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-View -ViewType VirtualMachine | Where {-not $_.Config.Template}"
# Para intrucciones del uso consulta: http://www.virtu-al.net/2010/01/27/powercli-virtual-machine-disk-usage/
$AllVMsView = Get-View -ViewType VirtualMachine | Where-Object {-not $_.Config.Template}
$VMGuestDiskInfo = $AllVMsView | Select-Object *, @{N="NumDisks";E={@($_.Guest.Disk.Length)}} | Sort-Object -Descending NumDisks
# Poblando la matriz
ForEach ($VM in $VMGuestDiskInfo){
# Número de disco inicial en 0 para cada máquina virtual
 $DiskNum = 0
 Foreach ($Disk in $VM.Guest.Disk){
    $VMID = $VM.MoRef
    $Name = $VM.name
    $DiskNum = $DiskNum -as [INT]
    $DiskPath = $Disk.DiskPath
    $DiskCapacityGB = ([math]::Round($disk.Capacity/ 1GB)) -as [INT]
    $DiskFreeSpaceGB = ([math]::Round($disk.FreeSpace / 1GB)) -as [INT]
    $DiskCapacityMB = ([math]::Round($disk.Capacity/ 1MB)) -as [INT]
    $DiskFreeSpaceMB = ([math]::Round($disk.FreeSpace / 1MB)) -as [INT]
# Creando SQL INSERT
$SQLVMGuestDiskInsert = "USE $SQLDatabase
INSERT INTO ocvs.VMDiskUsage (LastUpdated, VMID, Name, DiskNum, DiskPath, DiskCapacityGB, DiskFreeSpaceGB, DiskCapacityMB, DiskFreeSpaceMB)
VALUES('$LastUpdated', '$VMID', '$Name', '$DiskNum', '$DiskPath', '$DiskCapacityGB', '$DiskFreeSpaceGB', '$DiskCapacityMB', '$DiskFreeSpaceMB');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLVMGuestDiskInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
# Incrementando el número de disco
$DiskNum++
 } 
}
############################################################################################
# Inserción en la tabla SQL de VMNIC
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VM | Get-NetworkAdapter | Select *"
# Ejecutando CMD
$VMNetworkAdapters = Get-VM | Get-NetworkAdapter | Select-Object *
# Insertar cada fila
ForEach ($VMNetworkAdapter in $VMNetworkAdapters)
{
$VMID = $VMNetworkAdapter.ParentId
$Parent = $VMNetworkAdapter.Parent
$NICID = $VMNetworkAdapter.Id
$Name = $VMNetworkAdapter.Name
$MacAddress = $VMNetworkAdapter.MacAddress
$NetworkName = $VMNetworkAdapter.NetworkName
$ConnectionState = $VMNetworkAdapter.ConnectionState
$WakeOnLanEnabled = $VMNetworkAdapter.WakeOnLanEnabled
$Type = $VMNetworkAdapter.Type
# Creando SQL INSERT
$SQLNICInsert = "USE $SQLDatabase
INSERT INTO ocvs.VMNICs (LastUpdated, VMID, Parent, NICID, Name, MacAddress, NetworkName, ConnectionState, WakeOnLanEnabled, Type)
VALUES('$LastUpdated', '$VMID', '$Parent', '$NICID', '$Name', '$MacAddress', '$NetworkName', '$ConnectionState', '$WakeOnLanEnabled', '$Type');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLNICInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de almacenes de datos
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-Datastore | Select *"
# Ejecutando CMD
$Datastores = Get-Datastore | Select-Object *
# Insertar cada fila
ForEach ($Datastore in $Datastores)
{
$DatastoreID = $Datastore.Id
$Name = $Datastore.Name
$CapacityGB = $Datastore.CapacityGB -as [int]
$FreeSpaceGB = $Datastore.FreeSpaceGB -as [int]
$State = $Datastore.State
$Type = $Datastore.Type
$FileSystemVersion = $Datastore.FileSystemVersion -as [int]
$Accessible = $Datastore.Accessible
$StorageIOControlEnabled = $Datastore.StorageIOControlEnabled
$CongestionThresholdMillisecond = $Datastore.CongestionThresholdMillisecond -as [int]
$ParentFolderId = $Datastore.ParentFolderId
$ParentFolder = $Datastore.ParentFolder
$DatacenterId = $Datastore.DatacenterId
$Datacenter = $Datastore.Datacenter
$Uid = $Datastore.Uid
# Creando SQL INSERT
$SQLDatastoreInsert = "USE $SQLDatabase
INSERT INTO ocvs.Datastores (LastUpdated, DatastoreID, Name, CapacityGB, FreeSpaceGB, State, Type, FileSystemVersion, Accessible, 
StorageIOControlEnabled, CongestionThresholdMillisecond, ParentFolderId, ParentFolder, DatacenterId, Datacenter, Uid)
VALUES('$LastUpdated', '$DatastoreID', '$Name', '$CapacityGB', '$FreeSpaceGB', '$State', '$Type', '$FileSystemVersion', '$Accessible', 
'$StorageIOControlEnabled', '$CongestionThresholdMillisecond', '$ParentFolderId', '$ParentFolder', '$DatacenterId', '$Datacenter', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDatastoreInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL PortGroups
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VirtualPortGroup | Select *"
# Ejecutando CMD
$VirtualPortGroups = Get-VirtualPortGroup | Select-Object *
# Insertar cada fila
ForEach ($VirtualPortGroup in $VirtualPortGroups)
{
$VirtualSwitchId = $VirtualPortGroup.VirtualSwitchId
$Name = $VirtualPortGroup.Name
$VirtualSwitch = $VirtualPortGroup.VirtualSwitch
$VirtualSwitchName = $VirtualPortGroup.VirtualSwitchName
$PortGroupKey = $VirtualPortGroup.Key
$VLanId = $VirtualPortGroup.VLanId -as [int]
$VMHostId = $VirtualPortGroup.VMHostId
$VMHostUid = $VirtualPortGroup.VMHostUid
$Uid = $VirtualPortGroup.Uid
# Creando SQL INSERT
$SQLPortGroupInsert = "USE $SQLDatabase
INSERT INTO ocvs.PortGroups (LastUpdated, VirtualSwitchId, Name, VirtualSwitch, VirtualSwitchName, PortGroupKey, VLanId, VMHostId, VMHostUid, Uid)
VALUES('$LastUpdated', '$VirtualSwitchId', '$Name', '$VirtualSwitch', '$VirtualSwitchName', '$PortGroupKey', '$VLanId', '$VMHostId', '$VMHostUid', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLPortGroupInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de hosts 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-VMHost | Select Id,Name,State,ConnectionState,PowerState,NumCpu,CpuTotalMhz,CpuUsageMhz,MemoryTotalGB,MemoryUsageGB,ProcessorType,HyperthreadingActive,TimeZone,Version,Build"
"Por cada Host Ejecuta Get-Datastore/VirtualPortGroup/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutar CMD, no usar *, ya que encontré que esto no siempre responde en vSphere 6.5 en adelante
$Hosts = Get-VMHost | Select-Object Id,Name,State,ConnectionState,PowerState,NumCpu,CpuTotalMhz,CpuUsageMhz,MemoryTotalGB,MemoryUsageGB,ProcessorType,HyperthreadingActive,TimeZone,Version,Build
ForEach ($ESXiHost in $Hosts)
{
$HostID = $ESXiHost.Id
$Name = $ESXiHost.Name
$State = $ESXiHost.State
$ConnectionState = $ESXiHost.ConnectionState
$PowerState = $ESXiHost.PowerState
$NumCpu = $ESXiHost.NumCpu -as [int]
$CpuTotalMhz = $ESXiHost.CpuTotalMhz -as [int]
$CpuUsageMhz = $ESXiHost.CpuUsageMhz -as [int]
$MemoryTotalGB = $ESXiHost.MemoryTotalGB -as [int]
$MemoryUsageGB = $ESXiHost.MemoryUsageGB -as [int]
$ProcessorType = $ESXiHost.ProcessorType
$HyperthreadingActive = $ESXiHost.HyperthreadingActive
$TimeZone = $ESXiHost.TimeZone
$Version = $ESXiHost.Version -as [int]
$Build = $ESXiHost.Build -as [int]
$Parent = $ESXiHost.Parent
$IsStandalone = $ESXiHost.IsStandalone
$VMSwapfileDatastore = $ESXiHost.VMSwapfileDatastore
$StorageInfo = $ESXiHost.StorageInfo
$NetworkInfo = $ESXiHost.NetworkInfo -as [int]
$DiagnosticPartition = $ESXiHost.DiagnosticPartition
$FirewallDefaultPolicy = $ESXiHost.FirewallDefaultPolicy
$ApiVersion = $ESXiHost.ApiVersion -as [int]
$MaxEVCMode = $ESXiHost.MaxEVCMode
$Manufacturer = $ESXiHost.Manufacturer
$Model = $ESXiHost.Model
$DatastoreIdList = $ESXiHost.DatastoreIdList
$Uid = $ESXiHost.Uid
# Obteniendo totales por cada host
$HostDatastoreCount = Get-VMHost -Name $Name | Get-Datastore
$HostDatastores = $HostDatastoreCount.Count
$HostPortGroupCount = Get-VMHost -Name $Name | Get-VirtualPortGroup
$HostPortGroups = $HostPortGroupCount.Count
$HostVMCount = Get-VMHost -Name $Name | Get-VM
$HostVMs = $HostVMCount.Count
$HostVMDiskCount = Get-VMHost -Name $Name | Get-VM | Get-HardDisk
$HostVMDisks = $HostVMDiskCount.Count
$HostVMNICCount = Get-VMHost -Name $Name | Get-VM | Get-NetworkAdapter
$HostVMNICs = $HostVMNICCount.Count
# Creando SQL INSERT
$SQLHostInsert = "USE $SQLDatabase
INSERT INTO ocvs.Hosts (LastUpdated, HostID, Name, VMs, VMDisks, VMNICs, Datastores, PortGroups, State, ConnectionState, PowerState, NumCpu, CpuTotalMhz, CpuUsageMhz, MemoryTotalGB, 
MemoryUsageGB, ProcessorType, HyperthreadingActive, TimeZone, Version, Build, Parent, IsStandalone, VMSwapfileDatastore, StorageInfo, NetworkInfo, 
DiagnosticPartition, FirewallDefaultPolicy, ApiVersion, MaxEVCMode, Manufacturer, Model, DatastoreIdList, Uid)
VALUES('$LastUpdated', '$HostID', '$Name', '$HostVMs', '$HostVMDisks', '$HostVMNICs', '$HostDatastores', '$HostPortGroups', '$State', '$ConnectionState', '$PowerState', '$NumCpu', '$CpuTotalMhz', '$CpuUsageMhz', '$MemoryTotalGB', 
'$MemoryUsageGB', '$ProcessorType', '$HyperthreadingActive', '$TimeZone', '$Version', '$Build', '$Parent', '$IsStandalone', '$VMSwapfileDatastore', '$StorageInfo', '$NetworkInfo',
'$DiagnosticPartition', '$FirewallDefaultPolicy', '$ApiVersion', '$MaxEVCMode', '$Manufacturer', '$Model', '$DatastoreIdList', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLHostInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de clústeres 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecutando Get-Cluster | Select *"
"Para cada Cluster Running Get-VMHost/Datastore/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutando CMD
$Clusters = Get-Cluster | Select-Object *
# Insertar cada fila
ForEach ($Cluster in $Clusters)
{
$ClusterID = $Cluster.Id
$Name = $Cluster.Name
$DrsEnabled = $Cluster.DrsEnabled
$DrsMode = $Cluster.DrsMode
$DrsAutomationLevel = $Cluster.DrsAutomationLevel
$HAEnabled = $Cluster.HAEnabled
$HAAdmissionControlEnabled = $Cluster.HAAdmissionControlEnabled
$HAFailoverLevel = $Cluster.HAFailoverLevel
$HARestartPriority = $Cluster.HARestartPriority
$HAIsolationResponse = $Cluster.HAIsolationResponse
$HATotalSlots = $Cluster.HATotalSlots
$HAUsedSlots = $Cluster.HAUsedSlots
$HAAvailableSlots = $Cluster.HAAvailableSlots
$HASlotCpuMHz = $Cluster.HASlotCpuMHz
$HASlotMemoryGB = $Cluster.HASlotMemoryGB
$HASlotNumVCpus = $Cluster.HASlotNumVCpus
$ParentId = $Cluster.ParentId
$ParentFolder = $Cluster.ParentFolder
$VMSwapfilePolicy = $Cluster.VMSwapfilePolicy
$VsanEnabled = $Cluster.VsanEnabled
$VsanDiskClaimMode = $Cluster.VsanDiskClaimMode
$EVCMode = $Cluster.EVCMode
$CustomFields = $Cluster.CustomFields
$Uid = $Cluster.Uid
# Obteniendo totales de los cluster (hace que esta tabla sea útil)
$ClusterHostCount = Get-Cluster -Name $Name | Get-VMHost
$ClusterHosts = $ClusterHostCount.Count
$ClusterDatastoreCount = Get-Cluster -Name $Name | Get-Datastore
$ClusterDatastores = $ClusterDatastoreCount.Count
$ClusterVMCount = Get-Cluster -Name $Name | Get-VM
$ClusterVMs = $ClusterVMCount.Count
$ClusterVMDiskCount = Get-Cluster -Name $Name | Get-VM | Get-HardDisk
$ClusterVMDisks = $ClusterVMDiskCount.Count
$ClusterVMNICCount = Get-Cluster -Name $Name | Get-VM | Get-NetworkAdapter
$ClusterVMNICs = $ClusterVMNICCount.Count
# Creando SQL INSERT
$SQLClusterInsert = "USE $SQLDatabase
INSERT INTO ocvs.Clusters (LastUpdated, ClusterID, Name, Hosts, VMs, VMDisks, VMNICs, Datastores, DrsEnabled, DrsMode, DrsAutomationLevel, HAEnabled, HAAdmissionControlEnabled, HAFailoverLevel, HARestartPriority, 
HAIsolationResponse, HATotalSlots, HAUsedSlots, HAAvailableSlots, HASlotCpuMHz, HASlotMemoryGB, HASlotNumVCpus, ParentId, ParentFolder, VMSwapfilePolicy, 
VsanEnabled, VsanDiskClaimMode, EVCMode, CustomFields, Uid)
VALUES('$LastUpdated', '$ClusterID', '$Name', '$ClusterHosts', '$ClusterVMs', '$ClusterVMDisks', '$ClusterVMNICs', '$ClusterDatastores', '$DrsEnabled', '$DrsMode', '$DrsAutomationLevel', '$HAEnabled', '$HAAdmissionControlEnabled', '$HAFailoverLevel', '$HARestartPriority', 
'$HAIsolationResponse', '$HATotalSlots', '$HAUsedSlots', '$HAAvailableSlots', '$HASlotCpuMHz', '$HASlotMemoryGB', '$HASlotNumVCpus', '$ParentId', '$ParentFolder', '$VMSwapfilePolicy',  
'$VsanEnabled', '$VsanDiskClaimMode', '$EVCMode', '$CustomFields', '$Uid');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLClusterInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Inserción en la tabla SQL de centros de datos 
############################################################################################
# Mostrando acción
"----------------------------"
"Ejecuta Get-Datacenter | Select *"
"Por cada DC Ejecuta Get-VMHost/Datastore/VirtualPortGroup/VM/HardDisk/NetworkAdapter para los totales"
# Ejecutando CMD
$Datacenters = Get-Datacenter | Select-Object *
# Inserting each row
ForEach ($Datacenter in $Datacenters)
{
$DatacenterID = $Datacenter.Id
$Name = $Datacenter.Name
$CustomFields = $Datacenter.CustomFields
$ParentFolderId = $Datacenter.ParentFolderId
$ParentFolder = $Datacenter.ParentFolder
$Uid = $Datacenter.Uid
$DatastoreFolderId = $Datacenter.DatastoreFolderId
# Obteniendo totales de los datacenter (hace que esta tabla sea útil)
$DCClusterCount = Get-Datacenter -Name $Name | Get-Cluster
$DCClusters = $DCClusterCount.Count
$DCHostCount = Get-Datacenter -Name $Name | Get-VMHost
$DCHosts = $DCHostCount.Count
$DCDatastoreCount = Get-Datacenter -Name $Name | Get-Datastore
$DCDatastores = $DCDatastoreCount.Count
$DCPortGroupCount = Get-Datacenter -Name $Name | Get-VirtualPortGroup
$DCPortGroups = $DCPortGroupCount.Count
$DCVMCount = Get-Datacenter -Name $Name | Get-VM
$DCVMs = $DCVMCount.Count
$DCVMDiskCount = Get-Datacenter -Name $Name | Get-VM | Get-HardDisk
$DCVMDisks = $DCVMDiskCount.Count
$DCVMNICCount = Get-Datacenter -Name $Name | Get-VM | Get-NetworkAdapter
$DCVMNICs = $DCVMNICCount.Count
# Creando SQL INSERT
$SQLDatacenterInsert = "USE $SQLDatabase
INSERT INTO ocvs.Datacenters (LastUpdated, DatacenterID, Name, Clusters, Hosts, VMs, VMDisks, VMNICs, Datastores, PortGroups, CustomFields, ParentFolderId, ParentFolder, Uid, DatastoreFolderId)
VALUES('$LastUpdated', '$DatacenterID', '$Name', '$DCClusters', '$DCHosts','$DCVMs', '$DCVMDisks', '$DCVMNICs', '$DCDatastores', '$DCPortGroups', '$CustomFields', '$ParentFolderId', '$ParentFolder', '$Uid', '$DatastoreFolderId');"
# Ejecutando el INSERT query
invoke-sqlcmd -query $SQLDatacenterInsert -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
}
############################################################################################
# Desconectando del vCenter OCVS
############################################################################################
"----------------------------"
"Disconnecting vCenter:$vCenterServerocvs"
Disconnect-VIServer -Force -Confirm:$false
############################################################################################
# Fin del script
############################################################################################