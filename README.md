debian-lemp
===========

[![Docker Stars](https://img.shields.io/docker/stars/peterhartmann/docker-lemp.svg)](https://hub.docker.com/r/peterhartmann/docker-lemp/)
[![Docker Pulls](https://img.shields.io/docker/pulls/peterhartmann/docker-lemp.svg)](https://hub.docker.com/r/peterhartmann/docker-lemp/)


For development only.

Don't use it in a product environment.

# Usage

    git clone https://github.com/peter-hartmann/docker-debian-lemp.git
    docker build -t peterhartmann/debian-lemp docker-debian-lemp/
    docker run -it --rm --name lemp -v $(pwd)/www/html:/var/www/html -v $(pwd)/lib/mysql:/var/lib/mysql -v $(pwd)/backup:/backup/ -e TZ=America/Chicago peterhartmann/debian-lemp
    docker run -dt --restart=always --name lemp -v $(pwd)/www/html:/var/www/html -v $(pwd)/lib/mysql:/var/lib/mysql -v $(pwd)/backup:/backup/ -e TZ=America/Chicago peterhartmann/debian-lemp
    docker exec -it lemp bash

# Detail

## MySQL
* user: root
* (No password)

## SSH
SSH is not supported. Use `docker exec` to enter the docker container.
