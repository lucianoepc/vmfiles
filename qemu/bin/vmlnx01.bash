#!/bin/bash

#Colores principales usados para presentar información (menu,...)
g_color_reset="\x1b[0m"
g_color_green1="\x1b[32m"
g_color_gray1="\x1b[90m"
g_color_cian1="\x1b[36m"
g_color_yellow1="\x1b[33m"
g_color_red1="\x1b[31m"

#Constantes usados durante la instalación y ejecución de la VM.
g_vm_name='vmlnx01'
g_core=2
g_thread_per_core=2
g_memory_size='20G'

# Socket IPC para el QEMU Monitor
g_monitor_socket="/dt1/qemu/sockets/monitor_${g_vm_name}.sock"

# > Crear el disco principal:
#   qemu-img create -f qcow2 /dt1/vdisks/vmfedsrv_1.qcow2 40G
g_vdisk_path_1="/dt2/vdisks/${g_vm_name}_1.qcow2"

# > Para generar la MAC se usara:
#   printf -v macaddr "52:54:%02x:%02x:%02x:%02x" $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff))
#   echo $macaddr
g_mac_address='52:54:91:b4:82:4d'

#Constantes usados solo durante la instalación de la VM.
g_iso_os_path='/tempo/isos/Fedora-Server-dvd-x86_64-41-1.4.iso'

#Constantes usados solo durante la ejecucion de la VM.

#Variables globales
g_options=''


_usage() {

    printf 'Usage:\n'
    printf '    %b%s.bash\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP SPICE_PORT\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP SPICE_PORT ENABLE_MONITOR\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf 'Donde:\n'
    printf '  > %bFLAG_SETUP %bindica la opción de la configuración. Si no se especifica, se considera "2". Sus valores son:%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b0%b: Instalar la VM.%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b1%b: Ejecutar la VM de modo interactivo (muestra la consola QEMU).%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b2%b: Ejecutar la VM de modo background  (no se muestra la consola QEMU y se ejecuta como demonio).%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '  > %bSPICE_PORT %bindica el puerto SPICE que se expone localmente (127.0.0.1). El puerto debe ser mayor a 1024, por ejemplo 5931.%b\n' "$g_color_green1" \
           "$g_color_gray1" "$g_color_reset"
    printf '  > %bENABLE_MONITOR %bSi es 0, indica que se desactiva el socket de monitoreo de QEMU. Por defecto es 1, es decir, esta activado socket IPC de monitoreo.%b\n' "$g_color_green1" \
           "$g_color_gray1" "$g_color_reset"
    printf 'Clonar una VM Linux:\n'
    printf '  1> Para generar la MAC se usara %b(se recomienda reusar las mac address almacenados en el onedrive)%b:\n' "$g_color_gray1" "$g_color_reset"
    printf '     %bprintf -v macaddr "52:54:%%02x:%%02x:%%02x:%%02x" $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff))%b\n' \
           "$g_color_green1" "$g_color_reset"
    printf '     %becho $macaddr%b\n' "$g_color_green1" "$g_color_reset"
    printf '  2> Copiar el disco principal:\n'
    printf '     %bcp /dt1/vdisks/%s_1.qcow2 /dt%bn%b/vdisks/vm%bxxxx%b_1.qcow2%b\n' "$g_color_green1" "$g_vm_name" "$g_color_gray1" "$g_color_green1" \
           "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '  3> Crear el script para ejecutar la VM clonada.\n'
    printf '     > Copiar el sript:\n'
    printf '       %bcp /dt1/qemu/bin/%s.bash /dt1/qemu/bin/vm%bxxxx%b.bash%b\n' "$g_color_green1" "$g_vm_name" "$g_color_gray1" "$g_color_green1" \
           "$g_color_reset"
    printf '     > Cambiar la configuración de la mac-address y la ruta del disco a usar en la VM:\n'
    printf '       %bvim /dt1/qemu/bin/vm%bxxxx%b.bash%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '  4> Inicializar la VM clonada en modo interactivo (mostrando el visor de qemu) y modificar las opciones:\n'
    printf '     > Iniciar la VM clonada en modo interactivo: "%b/dt1/qemu/bin/vm%bxxxx%b.bash 1%b"\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '     > Cambiar la IP del servidor %b(se recomienda reusar las mac address almacenados en el onedrive)%b:\n' "$g_color_gray1" "$g_color_reset"
    printf '       %bsudo nmcli connection modify enp0s2 ipv4.address 192.168.50.%bxx%b/24%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '       %bsudo nmcli connection modify enp0s2 ipv4.dns "192.168.2.202,8.8.8.8,200.48.225.130" ipv4.gateway 192.168.50.1%b\n' "$g_color_green1" \
           "$g_color_reset"
    printf '       %bnmcli con show enp0s2%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo nmcli con down enp0s2%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo nmcli con up enp0s2%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bip addr show%b\n' "$g_color_green1" "$g_color_reset"
    printf '     > Cambiar el nombre de equipo en "%b/etc/host%b"\n' "$g_color_gray1" "$g_color_reset"
    printf '       %bsudo vi /etc/hosts%b\n' "$g_color_green1" "$g_color_reset"
    printf '       Modificar o adiciona la ultima linea: "%b192.168.50.%bxx%b  vm%bxxxx%b.quyllur.home vm%bxxxx%b"\n' "$g_color_green1" "$g_color_gray1" \
           "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '     > Cambiar el nombre de la maquina: "%bsudo hostnamectl set-hostname vm%bxxxx%b.quyllur.home%b"\n' "$g_color_green1" "$g_color_gray1" \
           "$g_color_green1" "$g_color_reset"
    printf '     > Cambiar el machine-id:\n'
    printf '       %bsudo rm /etc/machine-id%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo systemd-machine-id-setup%b\n' "$g_color_green1" "$g_color_reset"
    printf '     > Regenerar la clave SSH del servidor SSH (sin passphrase):\n'
    printf '       %bsudo ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key%b\n' "$g_color_green1" "$g_color_reset"
    printf '       %bsudo ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key%b\n' "$g_color_green1" "$g_color_reset"
    printf '     > Apagar el servidor: "%bsudo shutdown -h now%b"\n' "$g_color_green1" "$g_color_reset"
    printf '  5> Opcionalmente, limpiar los server SSH de confianza registrados en el SSH cliente:\n'
    printf '     %bssh-keygen -f ~/.ssh/known_hosts -R "192.168.50.%bxx%b"%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '     %bssh-keygen -f ~/.ssh/known_hosts -R "vm%bxxxx%b.quyllur.home"%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"
    printf '  6> Iniciar la VM em modo background: "%b/dt1/qemu/bin/vm%bxxxx%b.bash%b"\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"

}


start_vm() {

    #1. Parametros
    local p_setup_flag=$1   #(0) Instalar la VM. 
                            #(1) Ejecutar la VM de modo interactivo.
                            #(2) Ejecutar la VM de modo background.
    local p_spice_port=$2

    local p_enable_monitor=1
    if [ "$3" = "0" ]; then
        p_enable_monitor=0
    fi


    #2. Calcular los opciones dinamicas de qemu

    #CPU, Procesador, Reloj de CPU es igual al del host
    g_options="--enable-kvm -name $g_vm_name -m ${g_memory_size} -M q35 -cpu host"
    #g_options="${g_options} -smp sockets=1,cores=${g_core},threads=${g_thread_per_core}"
    g_options="${g_options} -smp $((g_core * g_thread_per_core)) -rtc base=localtime"

    #Disco
    g_options="${g_options} -drive if=virtio,media=disk,index=0,cache=unsafe,file=${g_vdisk_path_1}"

    #Tarjeta de Red
    g_options="${g_options} -net nic,model=virtio-net-pci,macaddr=${g_mac_address} -net bridge,br=br0"

    #Tarjeta de sonido
    g_options="${g_options} -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0"

    #Definir el monitor
    g_options="${g_options} -vga virtio"
    #g_options="${g_options} -vga qxl"

    #Usar escritorio remoto SPICE
    if [ ! -z "$p_spice_port" ]; then

        g_options="${g_options} -vga qxl -spice port=${p_spice_port},addr=127.0.0.1,disable-ticketing=on"
    fi

    #Habilitar el monitor QEMU usando socket UNIX
    if [ $p_enable_monitor -ne 0 ]; then

        #Si existe el descriptor del socket IPC, eliminarlo.
        if [ -f "$g_monitor_socket" ]; then
            rm "$g_monitor_socket"
        fi
        g_options="${g_options} -monitor unix:${g_monitor_socket},server,nowait"
    fi
    
    #Opciones usados durante la instalación de la VM
    if [ $p_setup_flag -eq 0 ]; then
    
        #Montar el cd de instalador del SO (1ro busca en gestor de arranque en el disco, si no lo encuentra, busca en el CDROM)
        g_options="${g_options} -drive media=cdrom,index=1,file=${g_iso_os_path}"
    
    #Opciones usados durante la ejecución de la VM 
    else

        #Ejecutar como demonio
        if [ $p_setup_flag -eq 2 ]; then
            #No mostrar el visor de qemu, ejecutar como demonio
            g_options="${g_options} -display none -daemonize"
        fi
    
    fi

    if [ $p_enable_monitor -ne 0 ]; then
        printf 'Socket de monitoreo: "%b%s%b"\n' "$g_color_gray1" "$g_monitor_socket" "$g_color_reset"
    fi
    printf 'CPU Core           : "%b%s%b"\n' "$g_color_gray1" "$((g_core * g_thread_per_core))" "$g_color_reset"
    printf 'Disco           (1): "%b%s%b"\n' "$g_color_gray1" "$g_vdisk_path_1" "$g_color_reset"
    printf 'MAC Address        : "%b%s%b"\n\n' "$g_color_gray1" "$g_mac_address" "$g_color_reset"

    
    printf 'Start VM "%b%s%b"...\n%bqemu-system-x86_64%b %s%b\n' "$g_color_gray1" "$g_vm_name" "$g_color_reset" "$g_color_green1" "$g_color_gray1" "$g_options" "$g_color_reset"
    #return 0
    
    #3. Iniciar la VM
    qemu-system-x86_64 ${g_options}

}

#-------------------------------------------------------------------------------
#Codigo principal del script
#-------------------------------------------------------------------------------

#1. Parametros
gp_setup_flag=2     #(0) Instalar la VM. 
                    #(1) Ejecutar la VM de modo interactivo.
                    #(2) Ejecutar la VM de modo background.

if [ -z "$1" ] || [ "$1" = "2" ]; then
    gp_setup_flag=2
elif [ "$1" = "0" ]; then
    gp_setup_flag=0
elif [ "$1" = "1" ]; then
    gp_setup_flag=1
else
    printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "1" "$g_color_reset" "$g_color_gray1" "$1" "$g_color_reset"
    _usage
    exit 1
fi

gp_spice_port=''
if [ ! -z "$2" ]; then 
    if [[ "$2" =~ ^[0-9]+$ ]]; then
        if [ $2 -gt 1024 ]; then
            gp_spice_port=$2
        else
            printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "2" "$g_color_reset" "$g_color_gray1" "$2" "$g_color_reset"
            _usage
            exit 2
        fi
    else
        printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "2" "$g_color_reset" "$g_color_gray1" "$2" "$g_color_reset"
        _usage
        exit 2
    fi
fi

gp_enable_monitor=1
if [ "$3" = "0" ]; then
    gp_enable_monitor=0
fi

#Validar si el disco virtual de la VM existen
if [ ! -f "$g_vdisk_path_1" ]; then
    printf 'El archivo "%b%s%b", que representa al disco virtual de la VM "%b%s%b", no existe o no se tiene permisos.\n' "$g_color_gray1" "$g_vdisk_path_1" "$g_color_reset" \
           "$g_color_gray1" "$g_vm_name" "$g_color_reset"
    exit 3
fi

#Validar si la VM esta en ejecución (verifica un proceso 'qemu-system-x86_64' que use el disco asociado a la VM
#El primer caracter se usa '[]' (cojunto de caracteres usando expresion regular) para que se colocque en la busqueda el proceso grep del pipeline
if ps -fe | grep -E '[q]emu-system-x86_64.*'"$g_vdisk_path_1" &> /dev/null; then

    printf 'No puede iniciar la VM debido a que ya existe un proceso "%b%s%b" en ejecución y ha iniciado la VM "%b%s%b".\n' "$g_color_gray1" "qemu-system-x86_64" "$g_color_reset" \
           "$g_color_gray1" "$g_vm_name" "$g_color_reset"
    exit 3

fi


#¿validar si el puerto SPICE esta ocupado?


start_vm $gp_setup_flag "$gp_spice_port" $gp_enable_monitor

