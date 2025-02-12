#!/bin/bash

#Colores principales usados para presentar información (menu,...)
g_color_reset="\x1b[0m"
g_color_green1="\x1b[32m"
g_color_gray1="\x1b[90m"
g_color_cian1="\x1b[36m"
g_color_yellow1="\x1b[33m"
g_color_red1="\x1b[31m"


#Constantes usados solo durante la ejecucion de la VM.

#Variables globales
g_options=''


_usage() {

    printf 'Usage:\n'
    printf '    %b%s.bash\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf '    %b%s.bash FLAG_SETUP SPICE_PORT\n%b' "$g_color_yellow1" "$g_vm_name" "$g_color_reset"
    printf 'Donde:\n'

}

_check_server_is_shutdown() {

    local p_server="$1"

    local p_max_retries=100
    if [ ! -z "$2" ]; then
        p_max_retries=$2
    fi

    local p_retry_interval=5
    if [ ! -z "$3" ]; then
        p_retry_interval=$3
    fi

    printf 'Varificando que el servidor "%b%s%b" esta apagado...\n' "$g_color_gray1" "$p_server" "$g_color_reset"
    local l_retries=0
    local l_response
    local l_ok=1
    local l_status

    while [ $l_retries -lt $p_max_retries ]; do

        l_retries=$((l_retries + 1))

        #Intentar acceder al endpoint de healthz del API server
        ping -c 1 ${p_server} > /dev/null 2>&1
        l_status=$?

        if [ $l_status -ne 0 ]; then
            printf 'El servidor "%b%s%b" esta apagado.\n' "$g_color_gray1" "$p_server" "$g_color_reset"
            l_ok=0
            break
        fi
        
        if [ $l_retries -ne $p_max_retries ]; then
            printf '    El servidor "%b%s%b" aun esta en linea (cmd-code=%b%s%b) despues de su %s intento, esperando %s segundos para el siguiente intento...\n' \
                   "$g_color_gray1" "$p_server" "$g_color_reset" "$g_color_gray1" "$l_status" "$g_color_reset" "$l_retries" "$p_retry_interval"
            sleep $p_retry_interval
        fi
        
    done

    #Resultado
    if [ $l_ok -ne 0 ]; then
        printf 'Error: El servidor "%b%s%b" aun esta en linea despues de %b%s%b intentos.\n' "$g_color_gray1" "$p_server" "$g_color_reset" \
               "$g_color_gray1" "$l_retries" "$g_color_reset"
        return 1
    fi

    return 0

}


stop_k8s1() {

    #1. Parametros


    #2. Inicializar
    local l_aux=''
    local l_status

    #Verifica si el comando 'oc' está disponible
    if ! command -v oc &> /dev/null; then
        printf 'El comando "%b%s%b" no esta disponible. Favor de instalar el comando "%b%s%b" .\n' "$g_color_gray1" "oc" "$g_color_reset" \
               "$g_color_gray1" "oc" "$g_color_reset"
        return 2
    fi

    if ! command -v jq &> /dev/null; then
        printf 'El comando "%b%s%b" no esta disponible. Favor de instalar el comando "%b%s%b" .\n' "$g_color_gray1" "jq" "$g_color_reset" \
               "$g_color_gray1" "jq" "$g_color_reset"
        return 2
    fi

    if [ -z "$KUBECONFIG" ]; then
        printf 'La variable de entorno "%b%s%b" no esta disponible. Definir la variable con un archivo donde el contexto actual sea un usuario con el rol "%b%s%b" .\n' \
               "$g_color_gray1" "KUBECONFIG" "$g_color_reset" "$g_color_gray1" "cluster-admin" "$g_color_reset"
        return 2
    fi

    printf 'Variable de entorno "%b%s%b": "%b%s%b".\n' "$g_color_gray1" "KUBECONFIG" "$g_color_reset" "$g_color_gray1" "$KUBECONFIG" "$g_color_reset"

    l_aux=$(oc config current-context 2> /dev/null)
    l_status=$?
    if [ -z "$l_aux" ] || [ "$l_status" -ne 0 ]; then
        printf 'El archivos de configuracion "%b%s%b" no define un conecto actual valido.\n' "$g_color_gray1" "$KUBECONFIG" "$g_color_reset"
        return 2
    fi

    printf 'Contexto actual: "%b%s%b".\n' "$g_color_gray1" "$l_aux" "$g_color_reset"


    #3. Marcando todos los nodos como unschedulable
    printf 'Marcando todos los nodos del cluster como unschedulable ....\n'
    local l_node
    for l_node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
        printf 'Cordon el nodo "%b%s%b": %boc adm cordon %s%b\n' "$g_color_cian1" "$l_node" "$g_color_reset" "$g_color_gray1" "$l_node" "$g_color_reset"
        oc adm cordon ${l_node}
    done

    printf '\n\n'


    #4. Evacuar los pod (no estaticos, no deamonset) de los nodos trabajo
    printf 'Evacuar los pod (no estaticos, no deamonset) de los nodos de %b%s%b:\n\n' "$g_color_cian1" "trabajo" "$g_color_reset"
    for l_node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do
        echo ${node}
        printf 'Drain nodo "%b%s%b": %boc adm drain %s --delete-emptydir-data --ignore-daemonsets=true --timeout=15s --force%b\n' "$g_color_cian1" "$l_node" "$g_color_reset" \
               "$g_color_gray1" "$l_node" "$g_color_reset"
        oc adm drain ${l_node} --delete-emptydir-data --ignore-daemonsets=true --timeout=15s --force
        printf '\n\n'
    done


    #5. Deteniendo los nodos con un tiempo de espera de 1 minuto antes de apagado
    local l_wait_time=1

    printf 'Deteniendo todos los nodos del cluster....\n'
    for l_node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
        printf 'Deteniendo el nodo "%b%s%b" en %s minuto: %boc debug node/%s -- chroot /host shutdown -h %s%b\n' "$g_color_cian1" "$l_node" "$g_color_reset" "$l_wait_time" \
               "$g_color_gray1" "$l_node" "$l_wait_time" "$g_color_reset"
        oc debug node/${l_node} -- chroot /host shutdown -h ${l_wait_time}
    done

    printf '\n\n'


    #5. Verificar si el servidor esta activo
    local l_server='vmworker1.k8s1.quyllur.home'
    _check_server_is_shutdown "$l_server" 60 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'El servidor "%b%s%b" aun esta en linea. Detenga manualmente el balanceador "%b%s%b" cuando todos los nodos esten detenidos.\n' \
               "$g_color_gray1" "$l_server" "$g_color_reset" "$g_color_gray1" "haproxy" "$g_color_reset"
        return 3
    fi


    local l_server='vmmaster1.k8s1.quyllur.home'
    _check_server_is_shutdown "$l_server" 60 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'El servidor "%b%s%b" aun esta en linea. Detenga manualmente el balanceador "%b%s%b" cuando todos los nodos esten detenidos.\n' \
               "$g_color_gray1" "$l_server" "$g_color_reset" "$g_color_gray1" "haproxy" "$g_color_reset"
        return 3
    fi

    local l_server='vmmaster2.k8s1.quyllur.home'
    _check_server_is_shutdown "$l_server" 60 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'El servidor "%b%s%b" aun esta en linea. Detenga manualmente el balanceador "%b%s%b" cuando todos los nodos esten detenidos.\n' \
               "$g_color_gray1" "$l_server" "$g_color_reset" "$g_color_gray1" "haproxy" "$g_color_reset"
        return 3
    fi

    local l_server='vmmaster3.k8s1.quyllur.home'
    _check_server_is_shutdown "$l_server" 60 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'El servidor "%b%s%b" aun esta en linea. Detenga manualmente el balanceador "%b%s%b" cuando todos los nodos esten detenidos.\n' \
               "$g_color_gray1" "$l_server" "$g_color_reset" "$g_color_gray1" "haproxy" "$g_color_reset"
        return 3
    fi

    #6. Deteniendo el balanceador HAProxy
    printf 'Deteniendo el balanceador "%b%s%b"...\n' "$g_color_cian1" "haproxy" "$g_color_reset"

    if systemctl is-active haproxy.service 2>&1 > /dev/null; then
        printf 'La unidad systemd %b%s%b se esta deteniendo: "%b%s%b".\n' "$g_color_cian1" "haproxy.service" "$g_color_reset" \
               "$g_color_gray1" "systemctl stop haproxy.service" "$g_color_reset"
        sudo systemctl stop haproxy.service
    else
        printf 'La unidad systemd %b%s%b ya esta detenido.\n' "$g_color_gray1" "haproxy.service" "$g_color_reset"
    fi

}

#-------------------------------------------------------------------------------
#Codigo principal del script
#-------------------------------------------------------------------------------

#1. Parametros
gp_setup_flag=2     #(0) Instalar la VM. 
                    #(1) Ejecutar la VM de modo interactivo.
                    #(2) Ejecutar la VM de modo background.

#if [ -z "$1" ] || [ "$1" = "2" ]; then
#    gp_setup_flag=2
#elif [ "$1" = "0" ]; then
#    gp_setup_flag=0
#elif [ "$1" = "1" ]; then
#    gp_setup_flag=1
#else
#    printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "1" "$g_color_reset" "$g_color_gray1" "$1" "$g_color_reset"
#    _usage
#    exit 1
#fi
#
#gp_spice_port=''
#if [ ! -z "$2" ]; then 
#    if [[ "$2" =~ ^[0-9]+$ ]]; then
#        if [ $2 -gt 1024 ]; then
#            gp_spice_port=$2
#        else
#            printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "2" "$g_color_reset" "$g_color_gray1" "$2" "$g_color_reset"
#            _usage
#            exit 2
#        fi
#    else
#        printf 'Parametro %b%s%b, cuyo valor es "%b%s%b", es invalido.\n' "$g_color_gray1" "2" "$g_color_reset" "$g_color_gray1" "$2" "$g_color_reset"
#        _usage
#        exit 2
#    fi
#fi
#
#
##Validar si el disco virtual de la VM existen
#if [ ! -f "$g_vdisk_path" ]; then
#    printf 'El archivo "%b%s%b", que representa al disco virtual de la VM "%b%s%b", no existe o no se tiene permisos.\n' "$g_color_gray1" "$g_vdisk_path" "$g_color_reset" \
#           "$g_color_gray1" "$g_vm_name" "$g_color_reset"
#    exit 3
#fi
#
##¿validar si la VM esta en ejecución?
##¿validar si el puerto SPICE esta ocupado?

stop_k8s1

