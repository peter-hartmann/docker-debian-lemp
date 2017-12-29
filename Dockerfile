FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

## Install php
RUN apt-get update -qq && apt-get upgrade -y && \
    apt-get install -y wget apt-transport-https lsb-release ca-certificates && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update -qq && \
	apt-get install -y php7.1-fpm php7.1-mysql php7.1-gd php7.1-mcrypt php7.1-mysql php7.1-curl
	
## Install more
RUN apt-get install -y nginx \
                       curl \
					   expect \
					   nano

## Install mysql
RUN echo "mysql-server mysql-server/root_password password" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password" | debconf-set-selections && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-common mariadb-server mariadb-client && \
    rm -rf /var/lib/apt/lists/*

## Configuration
RUN sed -i 's/^listen\s*=.*$/listen = 127.0.0.1:9000/' /etc/php/7.1/fpm/pool.d/www.conf && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cgi.log/' /etc/php/7.1/fpm/php.ini && \
    sed -i 's/^\;error_log\s*=\s*syslog\s*$/error_log = \/var\/log\/php\/cli.log/' /etc/php/7.1/cli/php.ini

COPY files/root /

WORKDIR /var/www/html

VOLUME ["/var/www/", "/var/lib/mysql/", "/backup/"]

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh && bash
