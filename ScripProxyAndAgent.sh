#!/bin/bash
#

# VARIABLES DE CONFIGURACIÓN
#VARIABLE PARA LA FUNCION LOG SE USO $HOME PARA QUE CUALQUIER USUARIO QUE EJECUTE EL ARCHIVO CREE UN ARCHIVO LOG EN SU DIRECTORIO Y NO TENER PROBLEMAS DE PERMISOS
LOG_FILE="$HOME/script_logProxyAgent.txt" 

#VARIABLE PARA LA VERIFICACION DE SO
REQUIRED_OS_VERSION="22.04"

#************** DATOS ZABBIX PROXY *******************
ZABBIX_SERVER_IP="zabbix01.nubecentral.com:10051;zabbix02.nubecentral.com:10051"
ZABBIX_SERVER_IP_1="zabbix01.nubecentral.com"
ZABBIX_SERVER_IP_2="zabbix02.nubecentral.com"
#VALIDACION DE LA VERSION DEL PROXY zabbix
ZABBIX_PROXY_VERSION="6.0"

#UBICACION DE ARCHIVO DE CIFRADO
ZABBIX_PROXY_PSK="/opt/encrypted.key"

set -e  # Activar el modo de detener el script en caso de error

# Banners y funciones de mensajes
BannerGWS() {
  echo " 
  
                                                                   ..........
                                                            ...::----------::..
                                                          ..:------------------:..
                                                        ..:-----:::......::------:.
                                                        ..--::...          ..:------:::..
                                                         ....            ..:------------:..
                                                                         .:-:....  ....:--:
                      .........         ....                       ...    ... .............
                  .-+*########**=.    .=*#*=                      -*##+.    .=**#######**.
                .=*#####****######*:  .-*###.                    .*###=.  .=######**#####:
              .-*###*:..    ...=###+.  .+###=         ...        =###*:  .=###*...  .....
             .-###*-..          ....   .-*###:      .*##*:      .*###=.  .+###-
            .:###*-.                    .+###+     .+####*.     =###*.   .+####+:.
            .=###=.                      :*###:   .=######+.   :*###-     .=#########+:.
            .=###=.        .-======-.     +###+   -*##**##*=   =*##+        .:*##########*:
            .=###=.       .-#######*=     .*##*-.:+###:.###*:.:*###:            ...-+*#####+.
            .:*##*-.       .:---+##*=      =###+.=###-. :###+:=###+                   .:*###=
             .-####-..          +##*=      .*##*+###=.  .=###**##*.         ..         .=###+
              .-*###*-...  ....+###*=       -######+:    .+######-.       .=**:...   ..-###*-
                .=*######***######*-.        +####*-.    .:*####*..       -*#####****#####*-.
                  .:+**#######**=.           :*##*=.      .:*##*-.         .-+*########**-.
                      .........               ....          ....              ..........

            .:... ..... ........ :.....:....:.. ......    ..... .....      .:..::::::..:::::.
            .:... ....:  .:.::.. :.. .......:.. ......    ...:.  .:.     .:::.:..:.  .:......
            ..    .....  ......  :..........:.. ......    .....   .      ::...:....  ..:::::.
                                                                         .::::.                
  
  
  "
}

# Función para enviar mensajes al log y a la consola

log() {
  local message="$1"
  #echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
  echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

#************** DATOS ZABBIX AGENTE *******************
#VALIDACION DE LA VERSION DEL AGENTE2
ZABBIX_AGENT_VERSION="6.0"

#VALIDACION DEL HOSTNAME DEL AGENTE zabbix
# Obtener el hostname actual
hostname=$(hostname)

# Validar el hostname
if [ -n "$hostname" ]; then
    log "El hostname es válido: $hostname"
else
    log "El hostname no es válido."
    exit 1
fi

HOSTNAME_AGENT=$hostname

# OBTENER LA DIRECCIÓN IP ACTUAL DEL SISTEMA
IP_ACTUAL=$(hostname -I | awk '{print $1}' 2>/dev/null)

# COMPROBAR SI LA IP ES 127.0.0.1
if [ "$IP_ACTUAL" == "127.0.0.1" ]; then
    echo ""  # No se muestra nada si es 127.0.0.1
else
    echo "La dirección IP actual es: $IP_ACTUAL"
fi

#*****************************************************************************

#************** DATOS ZABBIX PROXY *******************************************
#VALIDACION DEL HOSTNAME DEL PROXY zabbix
# Solicitar al usuario que ingrese un dato
function Hostname_proxy (){
echo "Ingrese el Numero de Oportunidad para la creacion del Proxyname:"
read HOSTNAME_PROXY

# Validar si se ingresó un dato
if [ -z "$HOSTNAME_PROXY" ]; then
    log "¡Error! No se ingresó ningún dato, porfavor volver a intentar a ejecutar el Script"
    exit 1
else
    log "Has ingresado la siguiente Oportunidad: $HOSTNAME_PROXY para nombrar al Proxyname"
fi
}

#************** ENCRIPTACION DE ZABBIX PROXY *******************************************
# Generar una llave PSK de 32 bytes en formato hexadecimal
function key_Psk(){
PSK=$(openssl rand -hex 32)

# Mostrar la llave PSK
log "La llave PSK generada es: $PSK"

# Crear el archivo en /opt con el nombre encrypted.key
echo "$PSK" > /opt/encrypted.key
}

#**********************************************************************************************************

#************** BASE DE DATOS ***********************
#VARIABLES PARA INSTALACION DE MySQL
DB_NAME="zabbix_proxy"
DB_USER="zabbix"  # Usuario de MySQL (cámbialo si necesitas otro usuario)
DB_PASSWORD="password"  # Contraseña del usuario
#*****************************************************

# FUNCION PARA VALIDAR QUE EL USUARIO TENGA PERMISOS ROOT
function check_root() {

  log "=============================="
  log "Verificacion de root"
  log "=============================="
  if [ "$(whoami)" != "root" ]; then
    log "DEBE SER ROOT PARA INICIAR ESTE SCRIPT"
    exit 1
  else
    log "INICIANDO EJECUCION DE SCRIPT"
  fi
}

# Función para verificar que el sistema operativo sea Ubuntu 22.04
function check_os_version() {

  log "=============================="
  log "Verificando version de SO"
  log "=============================="
  # Obtener la versión de Ubuntu
  local os_version
  os_version=$(lsb_release -sr)

  # Validar si la versión es la requerida
  if [[ "$os_version" != "$REQUIRED_OS_VERSION" ]]; then
    log "Error: Este script requiere Ubuntu $REQUIRED_OS_VERSION. Actualmente estás usando Ubuntu $os_version."
    exit 1
  else
    log "Versión del sistema operativo válida: Ubuntu $os_version."
  fi
}


# Función para verificar la conectividad a IP y puertos
function check_connectivity() {
  log "=============================="
  log "Verificando conectividad a ZABBIX_SERVER_IP en puertos 10050 y 10051..."
  log "=============================="
  
  # Verificar si nc está instalado
  if ! command -v nc >/dev/null; then
    log "nc no está instalado. Intentando instalar..."

    # Intentar instalar netcat usando apt
    if sudo apt update && sudo apt install -y netcat; then
      log "nc instalado correctamente."
    else
      log "Error: No se pudo instalar nc. Por favor, instálelo manualmente y ejecute el script de nuevo"
      exit 1
    fi
	fi

  # Realizar la verificación de conectividad si nc está presente
  nc -zv $ZABBIX_SERVER_IP_1 10050 || { log "Error: No se puede conectar al puerto 10050"; exit 1; }
  nc -zv $ZABBIX_SERVER_IP_1 10051 || { log "Error: No se puede conectar al puerto 10051"; exit 1; }
  log "Conectividad verificada."
}

function BannerZabbixAgent2() {
  echo "
 #######    ##     ######   ######    ####    ##  ##              ##       ####   #######  ##   ##  ######    ####
 #   ##    ####     ##  ##   ##  ##    ##     ##  ##             ####     ##  ##   ##   #  ###  ##  # ## #   ##  ##
    ##    ##  ##    ##  ##   ##  ##    ##      ####             ##  ##   ##        ## #    #### ##    ##         ##
   ##     ##  ##    #####    #####     ##       ##     ######   ##  ##   ##        ####    ## ####    ##       ###
  ##      ######    ##  ##   ##  ##    ##      ####             ######   ##  ###   ## #    ##  ###    ##      ##
 ##    #  ##  ##    ##  ##   ##  ##    ##     ##  ##            ##  ##    ##  ##   ##   #  ##   ##    ##     ##  ##
 #######  ##  ##   ######   ######    ####    ##  ##            ##  ##     #####  #######  ##   ##   ####    ######
  
  "

}

# Función para instalar Zabbix Agent
function Install_zabbix_agent() {
  log "=============================="
  log "Instalando Zabbix Agent $ZABBIX_AGENT_VERSION en Ubuntu 22.04..."
  log "=============================="

  if ! command -v wget >/dev/null; then
    apt update && apt install -y wget
  fi
  
 #se agrego esta linea si el operador no actualizo preeviamente su servidor y solo ejecuto el script.
  apt update 
  wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu22.04_all.deb
  dpkg -i zabbix-release_latest+ubuntu22.04_all.deb
  apt update
  apt install -y zabbix-agent2 zabbix-agent2-plugin-* || { log "Error al instalar Zabbix Agent."; exit 1; }

  sed -i "s/^Server=.*/Server=$IP_ACTUAL/" /etc/zabbix/zabbix_agent2.conf
  sed -i "s/^Hostname=.*/Hostname=$HOSTNAME_AGENT/" /etc/zabbix/zabbix_agent2.conf
  sed -i '/^ServerActive/ s/^/#/' /etc/zabbix/zabbix_agent2.conf

  systemctl restart zabbix-agent2
  systemctl enable zabbix-agent2

  if systemctl is-active --quiet zabbix-agent2; then
    log "**********************"
    log "Zabbix Agent instalado y corriendo exitosamente."
    log "**********************"
  else
    log "Error al iniciar Zabbix Agent."
    exit 1
  fi
}


function BannerZabbixproxy() {
  echo "
 #######    ##     ######   ######    ####    ##  ##            ######   ######    #####   ##  ##   ##  ##
 #   ##    ####     ##  ##   ##  ##    ##     ##  ##             ##  ##   ##  ##  ##   ##  ##  ##   ##  ##
    ##    ##  ##    ##  ##   ##  ##    ##      ####              ##  ##   ##  ##  ##   ##   ####    ##  ##
   ##     ##  ##    #####    #####     ##       ##     ######    #####    #####   ##   ##    ##      ####
  ##      ######    ##  ##   ##  ##    ##      ####              ##       ## ##   ##   ##   ####      ##
 ##    #  ##  ##    ##  ##   ##  ##    ##     ##  ##             ##       ##  ##  ##   ##  ##  ##     ##
 #######  ##  ##   ######   ######    ####    ##  ##            ####     #### ##   #####   ##  ##    ####

  
  "

}

function Insta_Zabbix_Proxy(){

    log "=============================="
    log "Configuracion de ZABBIX PROXY"
    log "=============================="
	
apt install -y zabbix-proxy-mysql zabbix-sql-scripts || { log "Error al instalar Zabbix proxy."; exit 1; }
}



function BannerMysql() {
  echo "

 ##   ##  ##  ##    #####   #####   ####               #####   #######  ######   ##   ##  #######  ######
 ### ###  ##  ##   ##   ## ##   ##   ##               ##   ##   ##   #   ##  ##  ##   ##   ##   #   ##  ##
 #######  ##  ##   #       ##   ##   ##               #         ## #     ##  ##   ## ##    ## #     ##  ##
 #######   ####     #####  ##   ##   ##                #####    ####     #####    ## ##    ####     #####
 ## # ##    ##          ## ##   ##   ##   #                ##   ## #     ## ##     ###     ## #     ## ##
 ##   ##    ##     ##   ## ##  ###   ##  ##           ##   ##   ##   #   ##  ##    ###     ##   #   ##  ##
 ##   ##   ####     #####   #####   #######            #####   #######  #### ##     #     #######  #### ##
                               ###

"
}


# Función para instalar MySQL si no está instalado

function Inst_mysql() {
    log "=============================="
    log "Instalación de MySQL"
	log "=============================="

    # Actualizar e instalar MySQL si no está instalado
    if ! dpkg -l | grep -q mysql-server; then
        log "MySQL NO ESTÁ INSTALADO, SE PROCEDERÁ A LA INSTALACIÓN"
        apt update && apt install -y mysql-server || { log "Error al instalar mysql."; exit 1; }
    else
        log "MYSQL YA SE ENCUENTRA INSTALADO"
    fi

    # Verificar si la base de datos ya existe
    if mysql -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME;" >/dev/null 2>&1; then
        log "La base de datos '$DB_NAME' ya existe. No es necesario crearla."
    else
        log "La base de datos '$DB_NAME' no existe. Procediendo a crearla..."
		log "=============================="
		log "Configuracion de User, Pass y BD"
		log "=============================="
        mysql <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';  # Cambia 'password' si es necesario
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
quit
EOF
        log "La base de datos '$DB_NAME' se creó con éxito"
    fi
}

# Función para configurar la base de datos para Zabbix Proxy
function ZabbixBD() {
    log "=============================="
    log "Configuracion de MySQL"
    log "=============================="
    # Verificar si la tabla 'hosts' ya existe en la base de datos
    if mysql --default-character-set=utf8mb4 -u"$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME; SHOW TABLES LIKE 'hosts';" | grep -q "hosts"; then
        log "La base de datos '$DB_NAME' ya tiene la tabla 'hosts'. No se procederá a cargar el script."
    else
        log "Cargando la base de datos '$DB_NAME' desde el archivo SQL..."
        cat /usr/share/zabbix-sql-scripts/mysql/proxy.sql | mysql --default-character-set=utf8mb4 -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
        log "La carga de la base de datos se completó."
    fi
}

# Banners y funciones de mensajes
BannerConfZabbixProxy() {
  echo "
 
    ####    #####   ##   ##  #######                    ######   ######    #####   ##  ##   ##  ##            #######    ##     ######   ######    ####    ##  ##
  ##  ##  ##   ##  ###  ##   ##   #                     ##  ##   ##  ##  ##   ##  ##  ##   ##  ##            #   ##    ####     ##  ##   ##  ##    ##     ##  ##
 ##       ##   ##  #### ##   ## #                       ##  ##   ##  ##  ##   ##   ####    ##  ##               ##    ##  ##    ##  ##   ##  ##    ##      ####
 ##       ##   ##  ## ####   ####                       #####    #####   ##   ##    ##      ####               ##     ##  ##    #####    #####     ##       ##
 ##       ##   ##  ##  ###   ## #                       ##       ## ##   ##   ##   ####      ##               ##      ######    ##  ##   ##  ##    ##      ####
  ##  ##  ##   ##  ##   ##   ##        ##               ##       ##  ##  ##   ##  ##  ##     ##              ##    #  ##  ##    ##  ##   ##  ##    ##     ##  ##
   ####    #####   ##   ##  ####       ##              ####     #### ##   #####   ##  ##    ####             #######  ##  ##   ######   ######    ####    ##  ##


 
  "
}

# FUNCIÓN PARA INSTALAR Y CONFIGURAR ZABBIX PROXY
Config_zabbix_proxy() {

  log "=============================="
  log "configuracion de Zabbix Proxy"
  log "=============================="

  sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^Hostname=.*/Hostname=$HOSTNAME_PROXY/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^DBName=.*/DBName=zabbix_proxy/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^DBUser=.*/DBUser=zabbix/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^# DBPassword=.*/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^# TLSConnect=.*/TLSConnect=psk/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^# TLSAccept=.*/TLSAccept=psk/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s/^# TLSPSKIdentity=.*/TLSPSKIdentity=$HOSTNAME_PROXY/" /etc/zabbix/zabbix_proxy.conf
  sed -i "s|^# TLSPSKFile=.*|TLSPSKFile=$ZABBIX_PROXY_PSK|" /etc/zabbix/zabbix_proxy.conf

  systemctl restart zabbix-proxy
  systemctl enable zabbix-proxy

  if systemctl is-active --quiet zabbix-proxy; then
    log "**********************"
    log "Zabbix Proxy instalado y corriendo exitosamente."
    log "**********************"
  else
    log "Error al iniciar Zabbix Proxy."
    exit 1
  fi
}

# Funcion de Recargar la caché de configuración de Zabbix Proxy
RecargaCache() {

log "Recargando la caché de configuración de Zabbix Proxy..."
if zabbix_proxy -R config_cache_reload | grep -q "successful"; then
  log "La recarga de la caché de configuración fue exitosa."
else
  log "Error: No se pudo recargar la caché de configuración de Zabbix Proxy."
  exit 1
fi
}



log
BannerGWS
check_root
Hostname_proxy
key_Psk
check_os_version
check_connectivity
BannerZabbixAgent2
Install_zabbix_agent
BannerZabbixproxy
Insta_Zabbix_Proxy
BannerMysql
Inst_mysql
ZabbixBD
BannerConfZabbixProxy
Config_zabbix_proxy
RecargaCache

# Eliminar el script al finalizar
rm -- "zabbix-release_latest+ubuntu22.04_all.deb"
rm -- "$0"
