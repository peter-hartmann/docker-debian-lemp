FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

## Install php
RUN apt-get update -qq && apt-get upgrade -y && \
    apt-get install -y wget apt-transport-https lsb-release ca-certificates && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update -qq && \
    apt-get install -y php7.1-fpm php7.1-mysql php7.1-gd php7.1-mcrypt php7.1-mysql php7.1-curl php7.1-mbstring php7.1-x

## Install more
RUN apt-get install -y nginx \
                       curl \
                       expect \
                       nano

## Install mysql
RUN echo "mysql-server mysql-server/root_password password" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-common mariadb-server mariadb-client

## Install email
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Docker Postfix'" | debconf-set-selections && \
    apt-get -y install postfix && \
    rm -rf /var/lib/apt/lists/*

COPY files/root /

## Cleanup and Configuration
RUN sed -i 's/^listen\s*=.*$/listen = 127.0.0.1:9000/' /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cgi.log/' /etc/php/7.1/fpm/php.ini && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cli.log/' /etc/php/7.1/cli/php.ini

RUN postmap /etc/postfix/sasl/sasl_passwd && \
    chown root:root /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db && \
    chmod 0600      /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db && \
    cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf #https://ubuntuforums.org/showthread.php?t=2213546 

WORKDIR /var/www/html

VOLUME ["/var/www/", "/var/lib/mysql/", "/backup/"]

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh && bash
