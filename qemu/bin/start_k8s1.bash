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

#Función para aprobar los CSR pendientes
# 0 - No hay CSR pendientes
# 1 - Se aprobaron los CSR pendientes
# 2 - Error en obtener los CSR pendientes
_ocp_approve_pending_csrs() {

    local l_pending_csrs
    local l_status
    printf 'Verificando CSR pendientes...\n'

    #Obtener la lista de CSR pendientes
    l_pending_csrs=$(oc get csr -o json | jq -r '.items[] | select(.status == {} ) | .metadata.name')
    l_status=$?
    if [ $l_status -ne 0 ]; then
        printf 'Ocurrio un error al Obtener los CSR pendientes.\n'
        return 2
    fi

    if [ -z "$l_pending_csrs" ]; then
        printf 'No hay CSR pendientes de aprobación.\n'
        return 1
    fi

    #echo "Aprobando los siguientes CSR:"
    #echo "$pending_csrs"

    #Aprobar cada 'CSR pendiente'
    local l_csr
    for l_csr in $l_pending_csrs; do
        printf '    Aprobando CSR "%b%s%b": oc adm certificate approve %s\n' "$l_csr" "$l_csr"
        oc adm certificate approve "$l_csr"
    done

    echo "Todos los CSR pendientes han sido aprobados."
    return 0

}

_ocp_approve_all_csrs() {

    local p_max_retries=3
    if [ ! -z "$1" ]; then
        p_max_retries=$1
    fi

    local p_retry_interval=5
    if [ ! -z "$2" ]; then
        p_retry_interval=$2
    fi

    local l_status
    local l_retries=0
    local l_ok=1

    while [ $l_retries -lt $p_max_retries ]; do

        l_retries=$((l_retries + 1))

        _ocp_approve_pending_csrs

        l_status=$?
        if [ $l_status -ge 2 ]; then
            #printf 'Ocurrio un error al Obtener los CSR pendientes.\n'
            return 1
        fi
        
        if [ $l_retries -ne $p_max_retries ]; then
            printf 'Esperando %b%s%b segundos para encontrar nuevos CSR pendientes por aprobar (%b%s%b intento)...\n' "$g_color_gray1" "$p_retry_interval" "$g_color_reset" \
                   "$g_color_gray1" "$l_retries" "$g_color_reset"
            sleep $p_retry_interval
        fi

    done

    return 0

}

_check_server_health() {

    local p_url_health="$1"

    local p_max_retries=60
    if [ ! -z "$2" ]; then
        p_max_retries=$2
    fi

    local p_retry_interval=5
    if [ ! -z "$3" ]; then
        p_retry_interval=$3
    fi

    printf 'Varificando que el servicio "%b%s%b" esta activo...\n' "$g_color_gray1" "$p_url_health" "$g_color_reset"
    local l_retries=0
    local l_response
    local l_ok=1
    local l_status

    while [ $l_retries -lt $p_max_retries ]; do

        l_retries=$((l_retries + 1))

        #Intentar acceder al endpoint de healthz del API server
        l_response=$(curl -ks -o /dev/null -w "%{http_code}" "$p_url_health")
        l_status=$?

        if [ $l_status -eq 0 ] && [ "$l_response" == "200" ]; then
            printf 'El servicio "%b%s%b" esta activo...\n' "$g_color_gray1" "$p_url_health" "$g_color_reset"
            l_ok=0
            break
        fi
        
        if [ $l_retries -ne $p_max_retries ]; then
            printf '    El servicio "%b%s%b" aun no esta activo (cmd-core=%b%s%b, http-code=%b%s%b) despues de su %s intento, esperando %s segundos para el siguiente intento...\n' \
                   "$g_color_gray1" "$p_url_health" "$g_color_reset" "$g_color_gray1" "$l_status" "$g_color_reset" "$g_color_gray1" "$l_response" "$g_color_reset" \
                   "$l_retries" "$p_retry_interval"
            sleep $p_retry_interval
        fi
        
    done

    #Resultado
    if [ $l_ok -ne 0 ]; then
        printf 'Error: El servicio "%b%s%b" no esta activo despues de %b%s%b intentos.\n' "$g_color_gray1" "$p_url_health" "$g_color_reset" \
               "$g_color_gray1" "$l_retries" "$g_color_reset"
        return 1
    fi

    return 0

}


start_k8s1() {

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


    #3. Validando que el servidor DNS esta activo
    #resolvectl dns
    #resolvectl status
    #sudo systemd restart systemd-resolved
    #sudo systemctl restart lepc_setting_br0.service

    #4. Validando el servidor DNS
    l_aux=$(showmount -e 192.168.50.230 2> /dev/null)
    l_status=$?

    if [ -z "$l_aux" ] || [ "$l_status" -ne 0 ]; then
        printf 'El servidor NFS "%b%s%b", no esta habilitado o no expone como folderes compartidos.\n' "$g_color_gray1" "192.168.50.230" "$g_color_reset"
        return 2
    fi

    l_aux=$(echo "$l_aux" | grep 'k8s1registry' 2> /dev/null)
    l_status=$?

    if [ -z "$l_aux" ] || [ "$l_status" -ne 0 ]; then

        printf 'El servidor NFS "%b%s%b" no expone el folderes compartido "%b%s%b".\n' "$g_color_gray1" "192.168.50.230" "$g_color_reset" \
               "$g_color_gray1" "/k8s1registry" "$g_color_reset"
        return 2
    fi

    printf 'El servidor NFS "%b%s%b" esta operativo y expone el folderes compartido "%b%s%b".\n' "$g_color_gray1" "192.168.50.230" "$g_color_reset" \
           "$g_color_gray1" "/k8s1registry" "$g_color_reset"

    #5. Iniciando el balanceador HAProxy
    printf 'Ejecutando el balanceador "%b%s%b"...\n' "$g_color_cian1" "haproxy" "$g_color_reset"

    if systemctl is-active haproxy.service 2>&1 > /dev/null; then
        printf 'La unidad systemd %b%s%b ya esta iniciado.\n' "$g_color_gray1" "haproxy.service" "$g_color_reset"
    else
        printf 'La unidad systemd %b%s%b se esta iniciando: "%b%s%b".\n' "$g_color_cian1" "haproxy.service" "$g_color_reset" \
               "$g_color_gray1" "systemctl start haproxy.service" "$g_color_reset"
        sudo systemctl start haproxy.service
    fi

    #3. Iniciando los nodos maestros
    printf 'Iniciando los nodos %bmaestros%b:\n' "$g_color_cian1" "$g_color_reset"
    /dt1/qemu/bin/vmmaster1.k8s1.bash
    /dt1/qemu/bin/vmmaster2.k8s1.bash
    /dt1/qemu/bin/vmmaster3.k8s1.bash


    #4. Iniciando los nodos de trabajo
    printf 'Iniciando los nodos %btraabajo%b:\n' "$g_color_cian1" "$g_color_reset"
    /dt1/qemu/bin/vmworker1.k8s1.bash


    #5. Esperar que el API server esta activo
    _check_server_health 'https://api.k8s1.quyllur.home:6443/healthz' 60 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'Revise su infraestructura que no permite conexion con el API Server %b%s%b.\n' "$g_color_gray1" 'https://api.k8s1.quyllur.home:6443/healthz' "$g_color_reset"
        return 3
    fi

    #6. Iniciar sesion al cluster

    #Verificar si el usuario está autenticado en el clúster
    if ! oc whoami &> /dev/null; then
        #Realizar un oc login usando el contexto actual
        printf 'Error: No estás autenticado en el clúster. Por favor, inicia sesión con "oc login"\n.'
        return 3
    fi

    #7. Aprobar los CSR en forma reiteratiba hasta que no exista peticiones
    _ocp_approve_all_csrs 4 5
    l_status=$?
    
    if [ "$l_status" -ne 0 ]; then
        printf 'Ocurrio un error en aprobar los certificados. Realize la operacion manual y luego un %b%s%b a todos los nodos.\n' "$g_color_gray1" 'uncordon' "$g_color_reset"
        return 3
    fi


    #8. Uncordon los nodos
    local l_node
    for l_node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
        printf 'Uncordon el nodo "%b%s%b": %boc adm uncordon %s%b\n' "$g_color_cian1" "$l_node" "$g_color_reset" "$g_color_gray1" "$l_node" "$g_color_reset"
        oc adm uncordon ${l_node}
    done

    printf 'El cluster se inicio con exito.\nValidar el estado de los operadores de cluster usando: "%b%s%b".\n' "$g_color_gray1" 'oc get co' "$g_color_reset"

}

#-------------------------------------------------------------------------------
#Codigo principal del script
#-------------------------------------------------------------------------------

#1. Parametros
#gp_setup_flag=2     #(0) Instalar la VM. 
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

start_k8s1

