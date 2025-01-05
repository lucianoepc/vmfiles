#!/bin/bash

#Colores principales usados para presentar información (menu,...)
g_color_reset="\x1b[0m"
g_color_green1="\x1b[32m"
g_color_gray1="\x1b[90m"
g_color_cian1="\x1b[36m"
g_color_yellow1="\x1b[33m"
g_color_red1="\x1b[31m"

#Constantes usados durante la instalación y ejecución de la VM.
g_vm_name='vmphoenix'
g_core=2
g_thread_per_core=2
g_memory_size='8G'

# > Crear el disco principal:
#   qemu-img create -f qcow2 /dt1/vdisks/vmphoenix_1.qcow2 250G
g_vdisk_path="/dt1/vdisks/${g_vm_name}_1.qcow2"

# > Para generar la MAC se usara:
#   printf -v macaddr "52:54:%02x:%02x:%02x:%02x" $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff)) $(($RANDOM & 0xff))
#   echo $macaddr
g_mac_address='52:54:ec:58:03:08'

# BIOS UEFI
g_bios_path='/dt1/qemu/shared/uefi/OVMF_CODE.fd'

# BIOS UEFI> Storage persistente
g_bios_storage_path='/dt1/qemu/etc/vmphoenix_ovmf_var.fd'

#Constantes usados solo durante la instalación de la VM.
g_iso_os_path='/tempo/isos/Win11_23H2_Spanish_x64v2.iso'
g_iso_virtio_path='/dt1/qemu/shared/virtio/virtio-win-0.1.248.iso'

#Constantes usados solo durante la ejecucion de la VM.

#Variables globales
g_options=''


                    #(1) Ejecutar la VM de modo interactivo usando la consola QEMU.
                    #(2) Ejecutar la VM de modo background (sin driver de red/video 'virtio').
                    #(3) Ejecutar la VM de modo background (driver de red/video 'virtio').
_usage() {

    printf 'Usage:\n'
    printf '    %b%s.bash\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP SPICE_PORT RDP_PORT\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf 'Donde:\n'
    printf '  > %bFLAG_SETUP %bindica la opción de la configuración. Si no se especifica, se considera "3". Sus valores son:%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b0%b: Instalar la VM.%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b1%b: Ejecutar la VM en modo interactivo (usando la consola QEMU).%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b2%b: Ejecutar la VM en modo background  (demonio) y sin el driver de red//video "virtio".%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '    %b3%b: Ejecutar la VM de modo background  (demonio) y con el driver de red//video "virtio".%b\n' "$g_color_green1" "$g_color_gray1" "$g_color_reset"
    printf '  > %bSPICE_PORT %bindica el puerto SPICE que se expone localmente (127.0.0.1). Por defecto es 5930.%b\n' "$g_color_green1" \
           "$g_color_gray1" "$g_color_reset"
    printf '  > %bRDP_PORT %bindica el port-forwarding desde la VM al host del puerto RDP. Por ejemplo 3389.%b\n' "$g_color_green1" \
           "$g_color_gray1" "$g_color_reset"
    printf 'Clonar una VM Linux:\n'
    printf '  1> Para generar la MAC se usara:\n'
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
    printf '     > Cambiar la IP del servidor:\n'
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
    printf '  5> Iniciar la VM em modo background: "%b/dt1/qemu/bin/vm%bxxxx%b.bash%b"\n' "$g_color_green1" "$g_color_gray1" "$g_color_green1" "$g_color_reset"

}


star_vm() {

    #1. Parametros
    local p_setup_flag=$1   #(0) Instalar la VM. 
                            #(1) Ejecutar la VM de modo interactivo usando la consola QEMU.
                            #(2) Ejecutar la VM de modo background (sin driver de red/video 'virtio').
                            #(3) Ejecutar la VM de modo background (driver de red/video 'virtio').
    local l_spice_port=$2
    local l_rdp_port=$3

    #2. Iniciar el amulador de TMP
    #swtpm socket --tpmstate dir=/dt1/qemu/etc --ctrl type=unixio,path=/dt1/qemu/etc/vmphoenix_swtpm_sock --tpm2 -d
    #sleep 1

    #3. Calcular los opciones dinamicas de qemu

    #CPU, Procesador, Reloj de CPU es igual al del host
    g_options="--enable-kvm -name $g_vm_name -m ${g_memory_size} -M q35 -cpu host"
    g_options="${g_options} -smp $((g_core * g_thread_per_core)) -rtc base=localtime"
    #AMD ryzen no soporta ...
    #g_options="${g_options} -smp sockets=1,cores=${g_core},threads=${g_thread_per_core}"

    #Usar BIOS UEFI y su storage persistente de sus parametros
    g_options="${g_options} -drive if=pflash,format=raw,readonly=on,file=${g_bios_path}"
    g_options="${g_options} -drive if=pflash,format=raw,file=${g_bios_storage_path}"

    #Disco
    g_options="${g_options} -drive if=virtio,media=disk,index=0,cache=unsafe,file=${g_vdisk_path}"

    #Tarjeta de sonido
    g_options="${g_options} -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0"

    #Usar el escritorio remoto spice
    if [ ! -z "$l_spice_port" ]; then
        g_options="${g_options} -spice port=${l_spice_port},addr=127.0.0.1,disable-ticketing=on"
    fi

    #Opciones del emulador TMP
    #-tpmdev "passthrough,id=tpm0,path=/dev/tpm0" -device "tpm-tis,tpmdev=tpm0" -runas lucianoepc \
    #-chardev "socket,id=chrtpm,path=/dt1/qemu/etc/vmphoenix_swtpm_sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm" -device "tpm-tis,tpmdev=tpm0" \
    
    #Opciones usados durante la instalación de la VM
    if [ $p_setup_flag -eq 0 ]; then
   
        #Usando tarjeta de video sin soporte a virtio 
        g_options="${g_options} -vga qxl"

        #Tarjeta de red sin soporte a virtio
        #¿?

        #Montar el cd de instalador del SO (1ro busca en gestor de arranque en el disco, si no lo encuentra, busca en el CDROM)
        g_options="${g_options} -drive media=cdrom,index=1,file=${g_iso_os_path}"

        #Montar el cd del driver de virtio
        g_options="${g_options} -drive media=cdrom,index=2,file=${g_iso_virtio_path}"
   
    #Opciones usados durante la ejecución de la VM 
    else

        #Opciones de red/video virtio 
        if [ $p_setup_flag -eq 3 ]; then
        
            #Usando tarjeta de video con soporte a virtio 
            g_options="${g_options} -vga virtio"

            #Tarjeta de Red
            g_options="${g_options} -net nic,model=virtio-net-pci,macaddr=${g_mac_address} -net bridge,br=br0"
        
            #No mostrar el visor de qemu, ejecutar como demonio
            #g_options="${g_options} -daemonize"
        
        #Opciones de red/video genericos
        else
        
            #Usando tarjeta de video sin soporte a virtio 
            g_options="${g_options} -vga qxl"
            
            #Tarjeta de red sin soporte a virtio
            g_options="${g_options} -net nic,macaddr=${g_mac_address} -net bridge,br=br0"
        
        fi

        #Ejecutar como demonio
        if [ $p_setup_flag -ne 1 ]; then
            #No mostrar el visor de qemu, ejecutar como demonio
            g_options="${g_options} -daemonize"
        fi

        #Port-forwarding VM to Host: RDP port
        #-netdev user,id=x,hostfwd=[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
        if [ ! -z "$l_rdp_port" ]; then
            g_options="${g_options} -net user,hostfwd=tcp::${l_rdp_port}-:3389"
        fi
    
    fi
    
    printf 'Start VM "%b%s%b"...\n%bqemu-system-x86_64%b %s%b\n' "$g_color_gray1" "$g_vm_name" "$g_color_reset" "$g_color_green1" "$g_color_gray1" "$g_options" "$g_color_reset"
    #return 0
    
    #4. Iniciar la VM
    qemu-system-x86_64 ${g_options}


}

#-------------------------------------------------------------------------------
#Codigo principal del script
#-------------------------------------------------------------------------------

#1. Parametros
gp_setup_flag=3     #(0) Instalar la VM. 
                    #(1) Ejecutar la VM de modo interactivo usando la consola QEMU.
                    #(2) Ejecutar la VM de modo background (sin driver de red/video 'virtio').
                    #(3) Ejecutar la VM de modo background (driver de red/video 'virtio').

if [ -z "$1" ] || [ "$1" = "3" ]; then
    gp_setup_flag=3
elif [ "$1" = "0" ]; then
    gp_setup_flag=0
elif [ "$1" = "1" ]; then
    gp_setup_flag=1
elif [ "$1" = "2" ]; then
    gp_setup_flag=2
else
    printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "1" "$g_color_reset" "$g_color_gray1" "$1" "$g_color_reset"
    _usage
    exit 1
fi

gp_spice_port=5930
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

gp_rdp_port=''
if [ ! -z "$3" ]; then 
    if [[ "$3" =~ ^[0-9]+$ ]]; then
        if [ $3 -gt 1024 ]; then
            gp_rdp_port=$3
        else
            printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "3" "$g_color_reset" "$g_color_gray1" "$3" "$g_color_reset"
            _usage
            exit 3
        fi
    else
        printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "3" "$g_color_reset" "$g_color_gray1" "$3" "$g_color_reset"
        _usage
        exit 3
    fi
fi


#Validar si el disco virtual de la VM existen
if [ ! -f "$g_vdisk_path" ]; then
    printf 'El archivo "%b%s%b", que representa al disco virtual de la VM "%b%s%b", no existe o no se tiene permisos.\n' "$g_color_gray1" "$g_vdisk_path" "$g_color_reset" \
           "$g_color_gray1" "$g_vm_name" "$g_color_reset"
    exit 3
fi

#¿validar si la VM esta en ejecución?
#¿validar si el puerto SPICE esta ocupado?

star_vm $gp_setup_flag "$gp_spice_port" "$gp_rdp_port"


