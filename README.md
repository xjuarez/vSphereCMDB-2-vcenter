vSphereCMDB
¿Alguna vez ha tenido una situación en la que necesitaba saber la configuración que tenía una máquina virtual hace 1 mes? ¿Quería ver el uso histórico del disco de la VM? ¿Hacer un seguimiento del crecimiento de las máquinas virtuales en un clúster? ¿Alguien cambió el nombre de una máquina virtual y ya no puede encontrarla? Hoy, con solo un vCenter, una vez que se realiza el cambio, los datos desaparecen y no se puede ver lo que era antes.

Todos estos desafíos se pueden resolver mediante la creación de una base de datos de administración de cambios de vSphere (vCMDB). Con PowerShell y Microsoft SQL Server, es posible registrar toda la información de vSphere en una base de datos SQL por hora, día o semana. A continuación, puede informar fácilmente sobre los datos desde cualquier punto en el tiempo. Bastante útil ¿eh?

Para comenzar, instale un servidor SQL si aún no tiene uno (cualquier versión de Express funciona bien). Puedes obtenerlo aqui. A continuación, descargue el siguiente archivo zip:

vSphereCMDB.zip

Se incluyen 5 scripts de PowerShell para ejecutar en el siguiente orden:

vSphereCMDB-Auth.ps1
Le solicita que ingrese las credenciales del servidor SQL y vCenter para almacenarlas de forma segura para cada secuencia de comandos posterior. También instala los módulos SqlServer y PowerCLI si aún no están presentes en el host. Requiere ejecutar como administrador para instalar los módulos.

vSphereCMDB-Create.ps1
Crea automáticamente la base de datos en la que almacenar los datos de vSphere con la estructura requerida. Solo necesita ejecutarse una vez, pero puede repetirse con diferentes nombres de base de datos.

vSphereCMDB-Insert.ps1
Se conecta al vCenter especificado al comienzo del script, ejecuta varios get-* y luego inserta los datos en vCMDB. Esto debe ejecutarse con la frecuencia de actualización de la base de datos deseada (normalmente diaria o semanal). Cree copias para múltiples vCenters.

vSphereCMDB-Query.ps1
Contiene consultas de ejemplo que puede ejecutar en su vCMDB.

vSphereCMDB-Prune.ps1
Elimina cualquier registro de la base de datos más allá del número configurado de retención de días, predeterminado 365. Ejecute con la frecuencia que desee o no lo ejecute para una retención infinita.

Cada script está configurado para conectarse a una instancia SQLEXPRESS local, pero también puede cambiar fácilmente la variable para conectarse a un servidor SQL remoto. Si los módulos SqlServer o PowerCLI no están instalados en el host, se instalan automáticamente desde PSGallery.

Una vez que haya comenzado a registrar datos en su vCMDB, se sorprenderá de la información que ahora puede determinar y que antes desconocía. Estos son algunos de mis mejores ejemplos:

Todas las configuraciones de una máquina virtual, la más antigua, la última notificada, todo lo que hay en el medio
Porcentaje de crecimiento de máquinas virtuales a lo largo del tiempo
Todas las configuraciones de VMDK para una VM
Todas las configuraciones de VMNIC para una VM
Lista de grupos de puertos y configuración
Lista de hosts, configuración, máquinas virtuales totales, VMDK, NIC, almacenes de datos y grupos de puertos por host (¡excelente para equilibrar y ver si un host no está viendo todos los almacenes de datos que debería!)
Lista de clústeres, configuración y hosts totales, máquinas virtuales, VMDK, NIC y almacenes de datos y por clúster
Lista de centros de datos, configuración y clústeres totales, máquinas virtuales, VMDK, NIC, almacenes de datos y grupos de puertos por centro de datos
Ejemplo de informe de máquina virtual de vCMDB

...
