FROM centos:7

ARG USER_ID=114
ARG USER_NAME=ftpuser
ARG GROUP_ID=60
ARG GROUP_NAME=ftpuser

LABEL cn.magicarnea.description="Vsftpd Docker image based on Centos 7. Supports passive mode, SSL and virtual users." \
      cn.magicarnea.vendor="MagicArena" \
      cn.magicarnea.maintainer="everoctivian@gmail.com" \
      cn.magicarnea.versionCode=1 \
      cn.magicarnea.versionName="1.0.0"

ENV FTP_USER **String**
ENV FTP_PASS **Random**
ENV PASV_ADDRESS **IPv4**
ENV PASV_ADDR_RESOLVE NO
ENV PASV_ENABLE YES
ENV PASV_MIN_PORT 21100
ENV PASV_MAX_PORT 21110
ENV XFERLOG_STD_FORMAT NO
ENV LOG_STDOUT **Boolean**
ENV FILE_OPEN_MODE 0666
ENV LOCAL_UMASK 077
ENV SSL_ENABLE NO
ENV TLS_CERT tls.crt
ENV TLS_KEY tls.key
ENV REQUIRE_CERT NO
ENV CA_CERTS_FILE ca.crt

EXPOSE 20/tcp \
	   21/tcp

VOLUME /home/vsftpd
VOLUME /var/log/vsftpd
VOLUME /etc/vsftpd/cert

RUN yum -y update && \
    yum clean all && \
    yum install -y \
	  vsftpd \
      db4-utils \
	  db4 \
      iproute \
      nmap-ncat && \
    yum clean all

RUN groupadd -g ${GROUP_ID} \
            ${GROUP_NAME}
RUN useradd -u ${USER_ID} \
            -g ${GROUP_ID} \
            -s /sbin/nologin \
            ${USER_NAME}

COPY ./etc/vsftpd/banned_emails /etc/vsftpd/
COPY ./etc/vsftpd/chroot_list /etc/vsftpd/
COPY ./etc/vsftpd/vsftpd.conf /etc/vsftpd/
COPY ./etc/vsftpd/ftpusers /etc/vsftpd/
COPY ./etc/vsftpd/user_list /etc/vsftpd/
COPY ./etc/pam.d/vsftpd_virtual /etc/pam.d/
COPY install.sh /usr/sbin/

RUN chmod +x /usr/sbin/install.sh && \
    mkdir -p /home/vsftpd/ && \
    mkdir -p /var/log/vsftpd/ && \
    mkdir -p /etc/vsftpd/vuser_conf && \
    chown -R ${USER_NAME}:${GROUP_NAME} /home/vsftpd/

CMD ["/usr/sbin/install.sh"]
