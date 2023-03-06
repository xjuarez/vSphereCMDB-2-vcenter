############################################################################################
# Descripción:
# Secuencia de comandos de vSphere CMDB 2 de 5. Esta secuencia de comandos crea la base de datos en la instancia o el servidor SQL especificado.
# ¡IMPORTANTE! Si realiza algún cambio en las variables SQLInstance y SQLDatabase aquí, cámbielos también en los scripts 3,4,5.!
############################################################################################
# Requisitos:
# - Set-executionpolicy unrestricted en la computadora que ejecuta el script
# - Acceso a una instancia de servidor SQL con permisos suficientes para crear una base de datos vCMDB
############################################################################################
# Configure las siguientes variables para conectarse a la base de datos SQL
############################################################################################
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
# Crear la base de datos de vSphere CMDB
############################################################################################
$SQLCreateDB = "USE master;  
GO  
CREATE DATABASE $SQLDatabase
GO"
invoke-sqlcmd -query $SQLCreateDB -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Crear SCHEMAs para OP y ocvs
############################################################################################
$SQLCreateDB = "USE $SQLDatabase;  
GO  
CREATE SCHEMA op AUTHORIZATION dbo
GO"
invoke-sqlcmd -query $SQLCreateDB -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
#
$SQLCreateDB = "USE $SQLDatabase;  
GO  
CREATE SCHEMA ocvs AUTHORIZATION dbo
GO"
invoke-sqlcmd -query $SQLCreateDB -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-VM | select * + Get-VM | Get-VMGuest | select *
############################################################################################
$SQLCREATEVMs = "USE $SQLDatabase
    CREATE TABLE op.VMs (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    VMID varchar(50),
    Name varchar(255),
    PowerState varchar(20),
    Notes varchar(max),
    Guest varchar(255),
    NumCpu int,
    CoresPerSocket tinyint,
    MemoryGB int,
    VMHostId varchar(25),
    VMHost varchar(255),
    VApp varchar(255),
    FolderId varchar(255),
    Folder varchar(255),
    ResourcePoolId varchar(255),
    ResourcePool varchar(255),
    HARestartPriority varchar(50),
    HAIsolationResponse varchar(50),
    DrsAutomationLevel varchar(50),
    VMSwapfilePolicy varchar(50),
    VMResourceConfiguration varchar(50),
    Version varchar(10),
    UsedSpaceGB int,
    ProvisionedSpaceGB int,
    DatastoreIdList varchar(max),
    ExtensionData varchar(50),
    CustomFields varchar(255),
    Uid varchar(255),
    PersistentId varchar(50),
    OSFullName varchar(100),
    IPAddress varchar(max),
    State varchar(50),
    Hostname varchar(255),
    Nics varchar(max),
    GuestId varchar(255),
    RuntimeGuestId varchar(255),
    ToolsVersion varchar (100),
    ToolsVersionStatus varchar (100),
    GuestFamily varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEVMs -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-VM | Get-harddisk | select *
############################################################################################
$SQLCREATEVMDisks = "USE $SQLDatabase
    CREATE TABLE op.VMDisks (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    VMID varchar(255),
    Parent varchar(255),
    DiskID varchar(100),
    Name varchar(100),
    Filename varchar(max),
    CapacityGB int,
    Persistence varchar(25),
    DiskType varchar(25),
    StorageFormat varchar(25)
);"
invoke-sqlcmd -query $SQLCREATEVMDisks -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-View -ViewType VirtualMachine To Get Disk Info
############################################################################################
$SQLCREATEVMDiskUsage = "USE $SQLDatabase
    CREATE TABLE op.VMDiskUsage (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    VMID varchar(255),
    Name varchar(255),
    DiskNum int,
    DiskPath varchar(255),
    DiskCapacityGB int,
    DiskFreeSpaceGB int,
    DiskCapacityMB int,
    DiskFreeSpaceMB int
);"
invoke-sqlcmd -query $SQLCREATEVMDiskUsage -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para for Get-VM | Get-networkadapter | select *
############################################################################################
$SQLCREATEVMNICs = "USE $SQLDatabase
    CREATE TABLE op.VMNICs (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
    LastUpdated datetime,
	VMID varchar(255),
    Parent varchar(255),
    NICID varchar (100),
    Name varchar(100),
    MacAddress varchar(17),
    NetworkName varchar(255),
    ConnectionState varchar(255),
    WakeOnLanEnabled varchar(10),
    Type varchar(25)
);"
invoke-sqlcmd -query $SQLCREATEVMNICs -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-datastore | select *
############################################################################################
$SQLCREATEDatastores = "USE $SQLDatabase
    CREATE TABLE op.Datastores (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    DatastoreID varchar(100),
    Name varchar(255),
    CapacityGB int,
    FreeSpaceGB int,
    State varchar(25),
    Type varchar(25),
    FileSystemVersion int,
    Accessible varchar(25),
    StorageIOControlEnabled varchar(25),
    CongestionThresholdMillisecond int,
    ParentFolderId varchar(100),
    ParentFolder varchar(100),
    DatacenterId varchar(100),
    Datacenter varchar(100),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEDatastores -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-virtualportgroup | select *
############################################################################################
$SQLCREATEPortGroups = "USE $SQLDatabase
    CREATE TABLE op.PortGroups (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
    LastUpdated datetime, 
	VirtualSwitchId varchar(100),
    Name varchar(100),
    VirtualSwitch varchar(100),
    VirtualSwitchName varchar(100),
    PortGroupKey varchar(100),
    VLanId int,
    VMHostId varchar(100),
    VMHostUid varchar(255),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEPortGroups -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-vmhost | select *
############################################################################################
$SQLCREATEHosts = "USE $SQLDatabase
    CREATE TABLE op.Hosts (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    HostID varchar(100),
    Name varchar(255),
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    PortGroups int,
    State varchar(50),
    ConnectionState varchar(100),
    PowerState varchar(100),
    NumCpu int,
    CpuTotalMhz int,
    CpuUsageMhz int,
    MemoryTotalGB int,
    MemoryUsageGB int,
    ProcessorType varchar(100),
    HyperthreadingActive varchar(100),
    TimeZone varchar(25),
    Version int,
    Build int,
    Parent varchar(100),
    IsStandalone varchar(20),
    VMSwapfileDatastore varchar(255),
    StorageInfo varchar(100),
    NetworkInfo int,
    DiagnosticPartition varchar(100),
    FirewallDefaultPolicy varchar(100),
    ApiVersion int,
    MaxEVCMode varchar(100),
    Manufacturer varchar(255),
    Model varchar(255),
    Uid varchar(255),
    DatastoreIdList varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEHosts -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-cluster | select *
############################################################################################
$SQLCREATEClusters = "USE $SQLDatabase
    CREATE TABLE op.Clusters (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    ClusterID varchar(100),
    Name varchar(100),
    Hosts int,
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    DrsEnabled varchar(100),
    DrsMode varchar(100),
    DrsAutomationLevel varchar(100),
    HAEnabled varchar(100),
    HAAdmissionControlEnabled varchar(100),
    HAFailoverLevel int,
    HARestartPriority varchar(100),
    HAIsolationResponse varchar(100),
    HATotalSlots int,
    HAUsedSlots int,
    HAAvailableSlots int,
    HASlotCpuMHz int,
    HASlotMemoryGB int,
    HASlotNumVCpus int,
    ParentId varchar(100),
    ParentFolder varchar(100),
    VMSwapfilePolicy varchar(100),
    VsanEnabled varchar(100),
    VsanDiskClaimMode varchar(100),
    EVCMode varchar(100),
    CustomFields varchar(MAX),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEClusters -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-datacenter | select *
############################################################################################
$SQLCREATEDatacenters = "USE $SQLDatabase
    CREATE TABLE op.Datacenters (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    DatacenterID varchar(100),
    Name varchar(100),
    Clusters int,
    Hosts int,
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    PortGroups int,
    CustomFields varchar(max),
    ParentFolderId varchar(100),
    ParentFolder varchar(100),
    Uid varchar(255),
    DatastoreFolderId varchar (255)
);"
invoke-sqlcmd -query $SQLCREATEDatacenters -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
#
############################################################################################
# Creación de una tabla SQL para Get-VM | select * + Get-VM | Get-VMGuest | select *
############################################################################################
$SQLCREATEVMs = "USE $SQLDatabase
    CREATE TABLE ocvs.VMs (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    VMID varchar(50),
    Name varchar(255),
    PowerState varchar(20),
    Notes varchar(max),
    Guest varchar(255),
    NumCpu int,
    CoresPerSocket tinyint,
    MemoryGB int,
    VMHostId varchar(25),
    VMHost varchar(255),
    VApp varchar(255),
    FolderId varchar(255),
    Folder varchar(255),
    ResourcePoolId varchar(255),
    ResourcePool varchar(255),
    HARestartPriority varchar(50),
    HAIsolationResponse varchar(50),
    DrsAutomationLevel varchar(50),
    VMSwapfilePolicy varchar(50),
    VMResourceConfiguration varchar(50),
    Version varchar(10),
    UsedSpaceGB int,
    ProvisionedSpaceGB int,
    DatastoreIdList varchar(max),
    ExtensionData varchar(50),
    CustomFields varchar(255),
    Uid varchar(255),
    PersistentId varchar(50),
    OSFullName varchar(100),
    IPAddress varchar(max),
    State varchar(50),
    Hostname varchar(255),
    Nics varchar(max),
    GuestId varchar(255),
    RuntimeGuestId varchar(255),
    ToolsVersion varchar (100),
    ToolsVersionStatus varchar (100),
    GuestFamily varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEVMs -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-VM | Get-harddisk | select *
############################################################################################
$SQLCREATEVMDisks = "USE $SQLDatabase
    CREATE TABLE ocvs.VMDisks (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    VMID varchar(255),
    Parent varchar(255),
    DiskID varchar(100),
    Name varchar(100),
    Filename varchar(max),
    CapacityGB int,
    Persistence varchar(25),
    DiskType varchar(25),
    StorageFormat varchar(25)
);"
invoke-sqlcmd -query $SQLCREATEVMDisks -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-View -ViewType VirtualMachine To Get Disk Info
############################################################################################
$SQLCREATEVMDiskUsage = "USE $SQLDatabase
    CREATE TABLE ocvs.VMDiskUsage (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    VMID varchar(255),
    Name varchar(255),
    DiskNum int,
    DiskPath varchar(255),
    DiskCapacityGB int,
    DiskFreeSpaceGB int,
    DiskCapacityMB int,
    DiskFreeSpaceMB int
);"
invoke-sqlcmd -query $SQLCREATEVMDiskUsage -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para for Get-VM | Get-networkadapter | select *
############################################################################################
$SQLCREATEVMNICs = "USE $SQLDatabase
    CREATE TABLE ocvs.VMNICs (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
    LastUpdated datetime,
	VMID varchar(255),
    Parent varchar(255),
    NICID varchar (100),
    Name varchar(100),
    MacAddress varchar(17),
    NetworkName varchar(255),
    ConnectionState varchar(255),
    WakeOnLanEnabled varchar(10),
    Type varchar(25)
);"
invoke-sqlcmd -query $SQLCREATEVMNICs -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-datastore | select *
############################################################################################
$SQLCREATEDatastores = "USE $SQLDatabase
    CREATE TABLE ocvs.Datastores (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    DatastoreID varchar(100),
    Name varchar(255),
    CapacityGB int,
    FreeSpaceGB int,
    State varchar(25),
    Type varchar(25),
    FileSystemVersion int,
    Accessible varchar(25),
    StorageIOControlEnabled varchar(25),
    CongestionThresholdMillisecond int,
    ParentFolderId varchar(100),
    ParentFolder varchar(100),
    DatacenterId varchar(100),
    Datacenter varchar(100),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEDatastores -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-virtualportgroup | select *
############################################################################################
$SQLCREATEPortGroups = "USE $SQLDatabase
    CREATE TABLE ocvs.PortGroups (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
    LastUpdated datetime, 
	VirtualSwitchId varchar(100),
    Name varchar(100),
    VirtualSwitch varchar(100),
    VirtualSwitchName varchar(100),
    PortGroupKey varchar(100),
    VLanId int,
    VMHostId varchar(100),
    VMHostUid varchar(255),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEPortGroups -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-vmhost | select *
############################################################################################
$SQLCREATEHosts = "USE $SQLDatabase
    CREATE TABLE ocvs.Hosts (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime, 
    HostID varchar(100),
    Name varchar(255),
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    PortGroups int,
    State varchar(50),
    ConnectionState varchar(100),
    PowerState varchar(100),
    NumCpu int,
    CpuTotalMhz int,
    CpuUsageMhz int,
    MemoryTotalGB int,
    MemoryUsageGB int,
    ProcessorType varchar(100),
    HyperthreadingActive varchar(100),
    TimeZone varchar(25),
    Version int,
    Build int,
    Parent varchar(100),
    IsStandalone varchar(20),
    VMSwapfileDatastore varchar(255),
    StorageInfo varchar(100),
    NetworkInfo int,
    DiagnosticPartition varchar(100),
    FirewallDefaultPolicy varchar(100),
    ApiVersion int,
    MaxEVCMode varchar(100),
    Manufacturer varchar(255),
    Model varchar(255),
    Uid varchar(255),
    DatastoreIdList varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEHosts -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-cluster | select *
############################################################################################
$SQLCREATEClusters = "USE $SQLDatabase
    CREATE TABLE ocvs.Clusters (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    ClusterID varchar(100),
    Name varchar(100),
    Hosts int,
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    DrsEnabled varchar(100),
    DrsMode varchar(100),
    DrsAutomationLevel varchar(100),
    HAEnabled varchar(100),
    HAAdmissionControlEnabled varchar(100),
    HAFailoverLevel int,
    HARestartPriority varchar(100),
    HAIsolationResponse varchar(100),
    HATotalSlots int,
    HAUsedSlots int,
    HAAvailableSlots int,
    HASlotCpuMHz int,
    HASlotMemoryGB int,
    HASlotNumVCpus int,
    ParentId varchar(100),
    ParentFolder varchar(100),
    VMSwapfilePolicy varchar(100),
    VsanEnabled varchar(100),
    VsanDiskClaimMode varchar(100),
    EVCMode varchar(100),
    CustomFields varchar(MAX),
    Uid varchar(255)
);"
invoke-sqlcmd -query $SQLCREATEClusters -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Creación de una tabla SQL para Get-datacenter | select *
############################################################################################
$SQLCREATEDatacenters = "USE $SQLDatabase
    CREATE TABLE ocvs.Datacenters (
    RecordID int IDENTITY(1,1) PRIMARY KEY,
	LastUpdated datetime,
    DatacenterID varchar(100),
    Name varchar(100),
    Clusters int,
    Hosts int,
    VMs int,
    VMDisks int,
    VMNICs int,
    Datastores int,
    PortGroups int,
    CustomFields varchar(max),
    ParentFolderId varchar(100),
    ParentFolder varchar(100),
    Uid varchar(255),
    DatastoreFolderId varchar (255)
);"
invoke-sqlcmd -query $SQLCREATEDatacenters -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword
############################################################################################
# Fin del script
############################################################################################