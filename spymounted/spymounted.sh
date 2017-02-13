#!/usr/bin/env sh

#################################################################################

#################################################################################
##
##  Variables
## -----------
##
APP_NAME="$(basename $0)"
APP_DIR="$(dirname $0)"
APP_VER="1.0"
APP_WEB="http://www.sergiotocalini.com.ar/"
DIR_CONF="${APP_DIR}/${APP_NAME%.*}.conf"
DATE_NOW=`date "+%Y/%m/%d - %H:%M:%S"`
##
#################################################################################

#################################################################################
##
##  Functions
## -----------
##
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo "\nOptions:"
    echo "  -c, --configfile   FS Configuration list (default=${DIR_CONF})."
    echo "  -d, --mountdir     Mount directory."
    echo "  -h, --help         Displays this help message."
    echo "  -m, --mountpoint   Mount point."
    echo "  -t, --type         File system type."
    echo "  -v, --version      Display the version of ${APP_NAME%.*} and exit."
    echo "  -S, --mon-system   Monitoring system output (default=zabbix)."
    echo "\nPlease send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER} ( ${APP_WEB} )"
    exit 1
}

checkParams() {
    if [[ -z ${MONSYS} || "${MONSYS}" != @(zabbix|nagios) ]]; then
	echo "${APP_NAME%.*}: Monitoring system is not supported, use the default." 1>&2
	MONSYS="zabbix"
    fi

    if [[ -z ${TYPE} || -z ${DIR} || -z ${MNT} || -z ${DIR_CONF} ]]; then
	if [[ -z ${DIR_CONF} ]]; then
	    echo "${APP_NAME%.*}: Required arguments missing or invalid." 1>&2
	    usage
	elif ! [[ -f ${DIR_CONF} && -r ${DIR_CONF} ]]; then
	    echo "${APP_NAME%.*}: Configuration file doesn't exists ( ${DIR_CONF} )." 1>&2
	    usage
	fi
    fi
}

getMountFS() {
    local system=`uname -s`

    if [[ "${system}" = @(HP-UX|SunOS) ]]; then
	cat /etc/mnttab | awk '{print $3";"$2";"$1}'
    elif [ "${system}" = 'Linux' ]; then
	cat /etc/mtab | awk '{print $3";"$2";"$1}'
    fi
}

checkFS() {
    local fs="${1}"
    local dir="${2}"
    local mnt="${3}"

    mountedFS="$(getMountFS)"

    if [[ -n ${fs} && -n ${dir} && -n ${mnt} ]]; then
	for i in ${mountedFS}; do
	    local mfs=$(echo ${i} | awk -F ';' '{print $1}')
	    local mdir=$(echo ${i} | awk -F ';' '{print $2}')
	    local mpoint=$(echo ${i} | awk -F ';' '{print $3}')
	    if [[ "${fs}" = ${mfs} && "${dir}" = ${mdir} ]]; then
		if [[ "${mnt}" = ${mpoint} ]]; then
		    return 1
		fi
	    fi
	done
    fi

    return 0
}

##
#################################################################################

#################################################################################

count=0
for x in "${@}"; do
    ARG[$count]="$x"
    let "count=count+1"
done

count=1
for i in "${ARG[@]}"; do
    case "${i}" in
	-c|--configfile)
	    DIR_CONF=${ARG[$count]}
	    ;;
	-d|--mountdir)
	    DIR=${ARG[$count]}
	    ;;
	-h|--help)
	    usage
	    ;;
	-m|--mountpoint)
	    MNT=${ARG[$count]}
	    ;;
	-t|--type)
	    TYPE=${ARG[$count]}
	    ;;
	-v|--version)
	    version
	    ;;
	-S|--mon-system)
	    MONSYS=${ARG[$count]}
	    ;;
    esac
    let "count=count+1"
done

checkParams

ocount=0
fcount=0
if [[ -n "${TYPE}" && -n "${DIR}" && -n "${MNT}" ]]; then
    checkFS "${TYPE}" "${DIR}" "${MNT}"
    status="${?}"
    overall[${ocount}]="${status};${DIR}"
    if [ ${status} = 0 ]; then
	failed[${fcount}]="${DIR}"
    fi
else
    while IFS=';' read mtype mdir mpoint; do
	if [[ "${mtype}" != @(#*) ]]; then
	    checkFS "${mtype}" "${mdir}" "${mpoint}"
	    status="${?}"
	    overall[${ocount}]="${status};${mdir}"
	    if [ ${status} = 0 ]; then
		failed[${fcount}]="${mdir}"
		let "fcount=fcount+1"
	    fi
	    let "ocount=ocount+1"
	fi
    done < "${DIR_CONF}"
fi

if [ ${MONSYS} = "zabbix" ]; then
    if [ "${#failed[@]}" = 0 ]; then
	echo "1"
	exit 0
    else
	echo "0"
	exit 1
    fi
elif [ ${MONSYS} = "nagios" ]; then
    summary="${#failed[@]}/${#overall[@]}"
    if [ "${#failed[@]}" = 0 ]; then
	echo "OK: All filesystems are mounted ( ${#overall[@]} FS )."
	exit 0
    else
	echo "Warning: ${summary} filesystems are not mounted ( ${failed[@]} )."
	exit 1
    fi
fi
