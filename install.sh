#!/bin/bash

# If no env var for FTP_USER has been specified, use 'admin':
if [ "${FTP_USER}" = "**String**" ]; then
    export FTP_USER='admin'
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [ "${FTP_PASS}" = "**Random**" ]; then
    export FTP_PASS=`cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-16}`
fi

# Do not log to STDOUT by default:
if [ "${LOG_STDOUT}" = "**Boolean**" ]; then
    export LOG_STDOUT='NO'
else
    export LOG_STDOUT='YES'
fi

# Set passive mode parameters:
if [ "${PASV_ADDRESS}" = "**IPv4**" ]; then
    export PASV_ADDRESS=$(/sbin/ip route | awk '/default/ { print $3 }')
fi

export GLOBAL_CONFIG_FILE="/etc/vsftpd/vsftpd.conf"
export TLS_DIR="/etc/vsftpd/ssl"
export VIRTUAL_USER_HOME_DIR="/home/vsftpd/${FTP_USER}"
export VIRTUAL_USER_CONFIG_DIR="/etc/vsftpd/vuser_conf"
export VIRTUAL_USER_CONFIG_FILE="${VIRTUAL_USER_CONFIG_DIR}/${FTP_USER}"

# Create home dir and update vsftpd user db:
mkdir -p ${VIRTUAL_USER_HOME_DIR}
chown -R ftpuser:ftpuser /home/vsftpd/

mkdir -p ${VIRTUAL_USER_CONFIG_DIR}
touch ${VIRTUAL_USER_CONFIG_FILE}

# Create virtual users' config file.
echo "local_root=${VIRTUAL_USER_HOME_DIR}" >> ${VIRTUAL_USER_CONFIG_FILE}
echo "write_enable=YES" >> ${VIRTUAL_USER_CONFIG_FILE}
echo "anon_world_readable_only=NO" >> ${VIRTUAL_USER_CONFIG_FILE}
echo "anon_upload_enable=YES" >> ${VIRTUAL_USER_CONFIG_FILE}
echo "anon_mkdir_write_enable=YES" >> ${VIRTUAL_USER_CONFIG_FILE}
echo "anon_other_write_enable=YES" >> ${VIRTUAL_USER_CONFIG_FILE}

# Create virtual users' auth file.
echo -e "${FTP_USER}\n${FTP_PASS}" > /etc/vsftpd/vuser_passwd
/usr/bin/db_load -T -t hash -f /etc/vsftpd/vuser_passwd /etc/vsftpd/vuser_passwd.db

# Create global config file.
echo "pasv_enable=${PASV_ENABLE}" >> ${GLOBAL_CONFIG_FILE}
echo "pasv_address=${PASV_ADDRESS}" >> ${GLOBAL_CONFIG_FILE}
echo "pasv_addr_resolve=${PASV_ADDR_RESOLVE}" >> ${GLOBAL_CONFIG_FILE}
echo "pasv_max_port=${PASV_MAX_PORT}" >> ${GLOBAL_CONFIG_FILE}
echo "pasv_min_port=${PASV_MIN_PORT}" >> ${GLOBAL_CONFIG_FILE}
echo "file_open_mode=${FILE_OPEN_MODE}" >> ${GLOBAL_CONFIG_FILE}
echo "local_umask=${LOCAL_UMASK}" >> ${GLOBAL_CONFIG_FILE}
echo "xferlog_std_format=${XFERLOG_STD_FORMAT}" >> ${GLOBAL_CONFIG_FILE}

# Add tls options.
if [ "${SSL_ENABLE}" = "YES" ] || [ "${SSL_ENABLE}" = "yes" ]; then
	mkdir -p ${TLS_DIR}

	echo "ssl_enable=YES" >> ${GLOBAL_CONFIG_FILE}
	echo "allow_anon_ssl=NO" >> ${GLOBAL_CONFIG_FILE}
	echo "force_local_data_ssl=YES" >> ${GLOBAL_CONFIG_FILE}
	echo "force_local_logins_ssl=YES" >> ${GLOBAL_CONFIG_FILE}
	echo "ssl_tlsv1=YES" >> ${GLOBAL_CONFIG_FILE}
	echo "ssl_sslv2=NO" >> ${GLOBAL_CONFIG_FILE}
	echo "ssl_sslv3=NO" >> ${GLOBAL_CONFIG_FILE}
	echo "require_ssl_reuse=YES" >> ${GLOBAL_CONFIG_FILE}
	echo "ssl_ciphers=HIGH" >> ${GLOBAL_CONFIG_FILE}
	echo "rsa_cert_file=${TLS_DIR}/${TLS_CERT:-tls.crt}" >> ${GLOBAL_CONFIG_FILE}
	echo "rsa_private_key_file=${TLS_DIR}/${TLS_KEY:-tls.key}" >> ${GLOBAL_CONFIG_FILE}

    if [ "${REQUIRE_CERT}" = "YES" ] || [ "${REQUIRE_CERT}" = "yes" ]; then
        echo "require_cert=YES" >> ${GLOBAL_CONFIG_FILE}
        echo "validate_cert=YES" >> ${GLOBAL_CONFIG_FILE}
        echo "ca_certs_file=${TLS_DIR}/${CA_CERTS_FILE:-ca.crt}" >> ${GLOBAL_CONFIG_FILE}
    fi
fi

# Get log file path
export LOG_FILE=$(grep xferlog_file ${GLOBAL_CONFIG_FILE} | cut -d= -f2)

# stdout server info:
cat << EOB
	*************************************************
	*                                               *
	*    Docker image: magicarena/vsftpd            *
	*                                               *
	*************************************************

	SERVER SETTINGS
	---------------
	· FTP User: $FTP_USER
	· FTP Password: $FTP_PASS
	· Log file: $LOG_FILE
EOB

if [ "${LOG_STDOUT}" = "YES" ]; then
    /usr/bin/ln -sf /dev/stdout ${LOG_FILE}
    echo "    · Redirect vsftpd log to STDOUT: Yes."
else
    echo "    · Redirect vsftpd log to STDOUT: No."
fi

# Run vsftpd in background
&>/dev/null /usr/sbin/vsftpd ${GLOBAL_CONFIG_FILE} &
vsftpd_pid=$!

# Wait for port 21 to open
while :; do
    &>/dev/null nc -zv localhost 21
    if [ $? -eq 0 ]; then
        echo -e "\n    vsftpd listening on port 21"
        break
    fi
    sleep 1
done

# Re-attach to vsftpd
wait $vsftpd_pid
