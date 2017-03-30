#!/bin/bash
#
# restore_mysql.sh - MySQL restore using NETAPP FlexClone
# Created: Paulo Victor Maluf - 03/2017
#
# Parameters:
#
#   restore_mysql.sh --help
#
#    Parameter           Short Description                                                              Default
#    ------------------- ----- ------------------------------------------------------------------------ -----------------
#    --username             -u [OPTIONAL] MySQL username                                                backup
#    --password             -p [OPTIONAL] MySQL password                                                *******
#    --snap-name            -n [OPTIONAL] Snapshot name (See the --list option)
#    --cleanup              -c [OPTIONAL] Destroy volume clone and shutdown and remove docker image
#    --config-dir           -d [OPTIONAL] Config directory                                              ./cnf/common
#    --volume-name          -v [REQUIRED] Volume name (Ex: nfs_tester_db_2)
#    --mysql-version        -m [REQUIRED] MySQL version to be restored (Ex: 5.5, 5.6, 5.7)
#    --list                 -l [OPTIONAL] List snapshots
#    --restore-only         -r [OPTIONAL] Only take a restore of database without shutdown and destroy
#    --netapp-server        -s [REQUIRED] Netapp server
#    --help                 -h [OPTIONAL] help
#
#   Ex.: restore_mysql.sh [OPTIONS] --volume-name <NFS_VOLUMN> --netapp-server <SERVER> --mysql-version <MYSQL_VERSION>
#        restore_mysql.sh --volume-name nfs_mysql_tester_db_2 --netapp-server netapp-db-1.nas.infra --mysql-version 5.6
#        restore_mysql.sh -v nfs_teste_linux -s netapp-db-1.nas.infra --list
#
# Changelog:
#
# Date       Author               Description
# ---------- ------------------- ----------------------------------------------------
#====================================================================================

# Load .lib
source .lib $0

# Global Variables
MYUSER="backup"
MYPASS="YjRja3VwX000bjRnM3IK"
CONTAINER_IP="localhost"
MYSQL=`which mysql`
DOCKER=`which docker`
MYPORT=3306
SSH=`which ssh`
SSHUSER="mysql"
LOG="${SCRIPT_LOGDIR}/restore.log"
NFS_BASEDIR="/storage"
SUDO=`which sudo`
MOUNT=`which mount`
UMOUNT=`which umount`
CHOWN=`which chown`
CONFIG_DIR="$SCRIPT_DIR/cnf/common"
SNAP_NAME=""

# Functions
f_help(){
 head -30 $0 | tail -29
 exit 0
}

log(){
 MSG=$1
 COLOR=$2
 if [ "${COLOR}." == "blue." ]
  then
     echo -ne "\e[34;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "yellow." ]
    then
      echo -ne "\e[33;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "green." ]
    then
      echo -ne "\e[32;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "red." ]
    then
      echo -ne "\e[31;1m${MSG}\e[m" | tee -a ${LOG}
      sendmail ${MSG}
  else
    echo -ne "${MSG}" | tee -a ${LOG}
 fi
}

sendmail(){
MSG=$1
mailx -s "[RESTORE][MYSQL][${CONTAINER_IP}] Falha ao executar o restore" "${MAIL_LST}" << EOF
 Falha ao executar o restore usando o snapshot:
 ${MSG}
EOF
}

send_report(){
MSG_BODY=`tail -19 ${LOG} | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"`

if [[ ${MSG_BODY} =~ (NOK) ]]
 then
   MSG_TITLE="[RESTORE][MYSQL] ${SID} NOK"
 else
   MSG_TITLE="[RESTORE][MYSQL] ${SID} OK"
fi

mailx -s "${MSG_TITLE}" -r dba@ig.com "${MAIL_LST}" <<EOF
${MSG_BODY}
EOF
}

check_mysql_conn(){
 log "Checking MySQL connection on ${CONTAINER_IP}:${MYPORT}..." blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${CONTAINER_IP} -P ${MYPORT} -e "exit" > /dev/null 2>&1
 [ "$?." != "0." ] && { log "[ NOK ] Can't connect to MySQL! Please check your username and password.\n" red ;  exit 1 ;} || log "[ OK ]\n" green
}

check_ssh_conn(){
 log "Checking netapp ssh connectivity..." blue
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} exit > /dev/null 2>&1
 [ "$?." != "0." ] && { log "[ NOK ] Can't connect to NETAPP using ssh! Please check your credentials.\n" red ;  exit 1 ;} || log "[ OK ]\n" green
}

check_netapp_vol(){
 log "Checking netapp volume..." blue
 CHK=`${SSH} ${NETAPP_SERVER} snap list ${VOLUME_NAME} 2>&1 | grep 'does not exist' | wc -l`
 [ "${CHK}." != "0." ] && { log "[ NOK ] Volume: ${VOLUME_NAME} does not exists in NETAPP Server.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

snap_netapp_list(){
 log "Listing snapshots... \n" green
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} snap list ${VOLUME_NAME}
 exit 0
}

check_snapshot(){
 log "Checking snapshots..." blue
 CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} snap list ${VOLUME_NAME} 2>&1 | grep 'No snapshots exist' | wc -l`
 [ "${CHK}." != "0." ] && { log "[ NOK ] There is no snapshots in the volume: ${VOLUME_NAME}.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

get_snapshot(){
 if [ "${SNAP_NAME}." == "." ]
  then
    log "Getting the newest snapshot..." blue
    SNAP_NAME=`${SSH} ${SSHUSER}@${NETAPP_SERVER} snap list -n ${VOLUME_NAME} 2>&1 | awk '{print $4}' | grep -v '^$' | head -1`
    log "[ OK ]\n" green
    log "Using snapshot: " blue
    log "${SNAP_NAME}\n"
  else
    log "Using snapshot: " blue
    log "${SNAP_NAME}\n"
 fi
}

check_clone(){
 log "Checking if the clone already exists...." blue
 CHK=`showmount -e ${NETAPP_SERVER}|grep ${CLONE_NAME} | wc -l`
 [ "${CHK}." != "0." ] && { log "[ NOK ] Volume ${CLONE_NAME} already exists.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

create_clone(){
 log "Creating clone volume from snapshot..." blue
 CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} vol clone create ${CLONE_NAME} -b ${VOLUME_NAME} ${SNAP_NAME} 2>&1 | grep 'created successfully'| wc -l`
 [ "${CHK}." != "0." ] && { log "[ NOK ] Failed to create clone from snapshot.\n" red ; exit 1 ;} || log "[ OK ]\n" green
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} vol options ${CLONE_NAME} nosnapdir on
}

export_volume(){
 log "Exporting the volume..." blue 
 CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} exportfs -v -io rw=10.12.108.240,root=10.12.108.240 /vol/${CLONE_NAME} 2>&1 | grep 'exported' | wc -l`
 [ "${CHK}." == "0." ] && { log "[ NOK ] Failed to export the volume ${CLONE_NAME}.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

disable_snapdir(){
 log "Disable .snapshot directories..." blue
 CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} vol options ${CLONE_NAME} nosnapdir on`
 log "[ OK ]\n" green
}

mount_nfs(){
 log "Mounting nfs ${NFS}..." blue
 ${SUDO} mkdir -p "${NFS_BASEDIR}/${VOLUME_NAME}/data"
 ${SUDO} ${MOUNT} -o nfsvers=3 ${NETAPP_SERVER}:/vol/${CLONE_NAME} "${NFS}" 2>&1 > /dev/null
 CHK=`${SUDO} ${MOUNT} | grep ${CLONE_NAME} | wc -l`
 [ "${CHK}." == "0." ] && { log "[ NOK ] Failed to mount the volume: ${CLONE_NAME}.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

change_ownership(){
 log "Changing nfs ownership..." blue 
 ${SUDO} ${CHOWN} 999:999 ${NFS} -R
 [ "$?." != "0." ] && { log "[ NOK ] Failed to change ${NFS} ownership.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

start_docker(){
 log "Starting MySQL ${MYSQL_VERSION} docker image, this will take about 60 seconds..." blue
 ${SUDO} ${DOCKER} run --detach --name=${CLONE_NAME} -v ${NFS}/mysql/:/var/lib/mysql -v ${CONFIG_DIR}:/etc/mysql/conf.d mysql:${MYSQL_VERSION} 2>&1 > /dev/null
 sleep 60 ; CHK=`${SUDO} ${DOCKER} ps | grep ${CLONE_NAME} | wc -l`
 CHK=`${SUDO} ${DOCKER} ps | grep ${CLONE_NAME} | wc -l`
 [ "${CHK}." == "0." ] && { log "[ NOK ] Docker failed to started.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

get_container_ip(){
 log "Getting container ip..." blue
 CONTAINER_ID=`${SUDO} ${DOCKER} ps -aqf "name=${CLONE_NAME}"`
 CONTAINER_IP=`${SUDO} ${DOCKER} inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID}`
 [[ ! "${CONTAINER_IP}" =~ ^172 ]] && { log "[ NOK ] Failed to get container ip.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

run_mysql_test(){
 CONTAINER_IP=${CONTAINER_IP}
 log "Running mysql tests...\n" blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${CONTAINER_IP} -P ${MYPORT} -e "select count(1), table_schema from information_schema.tables group by table_schema;" 2> /dev/null ; CHK=$?
 [ "${CHK}." != "0." ] && { log "[ NOK ] Tests failed.\n" red ; exit 1 ;}
}

shutdown_docker(){
 log "Shutdown docker..." blue
 CHK=`${SUDO} ${DOCKER} ps -a | grep ${CLONE_NAME} | wc -l`
 if [ "${CHK}." == "1." ] 
  then
    ${SUDO} ${DOCKER} rm -f ${CLONE_NAME} 2>&1 > /dev/null ; CHK=$?
    [ "${CHK}." != "0." ] && { log "[ NOK ] Failed to shutdown docker container.\n" red ; exit 1 ;} || log "[ OK ]\n" green
  else
    log "[ OK ]\n" green
 fi
}

umount_nfs(){
 log "Umounting nfs ${NFS}..." blue
 CHK=`${SUDO} ${UMOUNT} ${NFS} 2>&1 > /dev/null`
 CHK=`${SUDO} ${MOUNT} | grep ${CLONE_NAME} | wc -l`
 [ "${CHK}." != "0." ] && { log "[ NOK ] Failed to umount the volume: ${CLONE_NAME}.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

take_clone_off(){
 log "Taking volune ${CLONE_NAME} offline..." blue
 CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} vol offline ${CLONE_NAME} 2>&1 | egrep '(is now offline|No volume named)' | wc -l`
 [ "${CHK}." == "0." ] && { log "[ NOK ] Fail to take volume: ${CLONE_NAME} offline.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

destroy_clone(){
 if [[ "${CLONE_NAME}" =~ ^clone_.*_tmp$ ]] 
  then 
   log "Destroy volune ${CLONE_NAME}..." blue
   CHK=`${SSH} ${SSHUSER}@${NETAPP_SERVER} vol destroy ${CLONE_NAME} -f 2>&1 | egrep "(Volume '${CLONE_NAME}' destroyed.|No volume named)" | wc -l`
   [ "${CHK}." == "0." ] && { log "[ NOK ] Fail to destroy volume: ${CLONE_NAME}.\n" red ; exit 1 ;} || log "[ OK ]\n" green
  else
   log "NOK"
 fi
}


# Parameters
for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
      --username)        args="${args}-u ";;
      --password)        args="${args}-p ";;
      --snap-name)       args="${args}-n ";;
      --cleanup)         args="${args}-c ";;
      --config-dir)      args="${args}-d ";;
      --volume-name)     args="${args}-v ";;
      --netapp-server)   args="${args}-s ";;
      --mysql-version)   args="${args}-m ";;
      --restore-only)    args="${args}-r ";;
      --list)            args="${args}-l ";;
      --help)            args="${args}-h ";;
      #pass through anything else
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- $args

while getopts ":hu:p:n:v:s:m:d:clr" PARAMETRO
do
    case $PARAMETRO in
        h) f_help;;
        u) MYUSER=${OPTARG[@]};;
        p) MYPASS=${OPTARG[@]};;
        n) SNAP_NAME=${OPTARG[@]};;
        c) CLEANUP="OK";;
        d) CONFIG_DIR=${OPTARG[@]};;
        v) VOLUME_NAME=${OPTARG[@]};;
        s) NETAPP_SERVER=${OPTARG[@]};;
        r) RESTORE_ONLY="OK";;
        m) MYSQL_VERSION=${OPTARG[@]};;
        l) SNAP_LIST="OK";;
        :) log "Option $arg requires an argument. Try --help for more information.\n" red; exit 1;;
        *) log "$arg is an unrecognized option. Try --help for more information.\n" red; exit 1;;
    esac
done

[ "$1" ] || f_help

#########################
# Main                  #
#########################
if [ ${VOLUME_NAME} ] && [ ${NETAPP_SERVER} ] && [ ${MYSQL_VERSION} ]
 then
   check_ssh_conn
   check_netapp_vol
   CLONE_NAME="clone_${VOLUME_NAME}_tmp"
   NFS="${NFS_BASEDIR}/${VOLUME_NAME}/data"
   if [ "${SNAP_LIST}." == "OK." ] 
    then 
      snap_netapp_list
    elif [ "${CLEANUP}." == "OK." ] 
      then 
       shutdown_docker
       umount_nfs
       take_clone_off
       destroy_clone
       log "Cleanup completed\n" green
    else
      check_snapshot
      get_snapshot
      check_clone
      create_clone
      export_volume
      disable_snapdir
      mount_nfs
      change_ownership
      start_docker
      get_container_ip
      check_mysql_conn
      run_mysql_test
      [ "${RESTORE_ONLY}." == "OK." ] && { log "Restore completed.\n" green ; exit 0 ; }
      shutdown_docker
      umount_nfs
      take_clone_off
      destroy_clone
      log "Restore completed\n" green 
      send_report
   fi
 else
   log "Options [--netapp-server|-n], [--volume-name|-v] and [--mysql-version|-m] are required." red
   log "\n"
   exit 1
fi
