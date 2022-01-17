#!/bin/bash

# forzar sudo

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "[!]Lanzar con sudo."
    exit 
fi

# comprobar interfaces

interfaces=("/sys/class/net/wlan0/" "/sys/class/net/eth0/")

for interfaz in "${interfaces[@]}";do
	if [ ! -d "${interfaz}" ]; then
		echo "[-]Interfaz ${interfaz} no encontrada."
		exit
	fi
	echo "[+]Interfaz ${interfaz} disponible"
done

# instalar dependencias

dependencias=("dnsmasq" "hostapd" "bridge-utils" "iptables-persistent")

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

for paquete in "${dependencias[@]}";do
	dpkg -s "${paquete}" > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "[!]${paquete} no encontrado. Instalando..."
		apt install -y ${paquete} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "[-]No se pudo instalar ${paquete}.Comprueba la conexión a Internet."
			exit
		fi
	fi
	echo "[+]${paquete} instalado."
done

# configurar ficheros

ficheros_conf=("/etc/dnsmasq.d/dnsmasq.conf" "/etc/dnsmasq.d/fakehosts.conf" "/etc/hostapd/hostapd.conf" "/etc/network/interfaces")

for fichero in "${ficheros_conf[@]}";do
	if [ -f "${fichero}" ]; then
		echo "[!]${fichero} encontrado. Realizando backup..."
		if [ -f "${fichero}.backup" ]; then
			echo "[!]Ya existe un backup del fichero..."
		else
			mv "${fichero}" "${fichero}.backup"
		fi
	fi
	cp "${fichero##*/}" "${fichero%/*}"
	echo "[+]${fichero} configurado."
done

# crear el bridge

if [ -d "/sys/class/net/br0/" ]; then
	ip link set br0 down > /dev/null 2>&1
	sleep 3
	brctl delbr br0 > /dev/null 2>&1
fi

brctl addbr br0 > /dev/null 2>&1
brctl addif br0 eth0 > /dev/null 2>&1
echo "[+]bridge configurado"

# habilitar enrutamiento de paquetes de manera persistente

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf > /dev/null 2>&1

# configurar directorio y fichero para reglas iptables 

fichero_reglas="/etc/iptables/rules.v4"

if [ -f "${fichero_reglas}" ]; then
	echo "[!]${fichero_reglas} encontrado. Realizando backup..."
	if [ -f "${fichero_reglas}.backup" ]; then
		echo "[!]Ya existe un backup del fichero..."
	else
		mv "${fichero_reglas}" "${fichero_reglas}.backup"
	fi		 
fi
mkdir -p /etc/iptables && touch /etc/iptables/rules.v4

# aplicamos regla y la guardamos en rules.v4

iptables -t nat -A POSTROUTING -o br0 -j MASQUERADE > /dev/null 2>&1
iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null 2>&1

# habilitar y arrancar el servicio netfilter-persistence

systemctl enable netfilter-persistent.service > /dev/null 2>&1
systemctl start netfilter-persistent.service > /dev/null 2>&1

# reiniciar servicio de red

service networking restart > /dev/null 2>&1

if [ $? -ne 0 ]; then
	echo "[-]Algo fue mal reiniciando el servicio. Comprueba el fichero interfaces."
	exit
fi
echo "[+]Punto de acceso configurado"

# preguntar para reiniciar

read -r -p "[!]Reiniciar ahora para aplicar los cambios?[y/N]: " response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
	reboot
fi
