#!/bin/bash

set -e

: ${WIKI_SITE_NAME:=MediaWiki}
: ${WIKI_SERVER_NAME:=localhost}
: ${WIKI_DB_NAME:=wiki}
: ${WIKI_DB_USER:=root}

if [ -z "$MYSQL_PORT_3306_TCP" ]; then
	echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable.'
	echo >&2 'Did you forget to --link some_mysql_container:mysql ?'
	exit 1
fi

if [[ -z "$WIKI_DB_PW" ]]; then
  WIKI_DB_PW=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi

# installation mode
if [[ ! -f ./wiki/.installed ]]; then
  cd wiki
  if [[ ! -n "${WIKI_SKIP_DB+1}" ]]; then
      #create new LocalSettings.php
      rm LocalSettings.php

      #create database
      TERM=dumb php -- "$MYSQL_PORT_3306_TCP" "$WIKI_DB_USER" "$WIKI_DB_PW" "$WIKI_DB_NAME" <<'EOPHP'
        <?php
          list($protocol, $host, $port) = explode(':', str_replace('/', '', $argv[1]));
          $mysql = new mysqli(str_replace('/', '', $host), $argv[2], $argv[3], '', (int)$port);
          if ($mysql->connect_error) {
            file_put_contents('php://stderr', 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
            exit(1);
          }
          if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
            file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
            $mysql->close();
            exit(1);
          }
          if ($argv[2] != 'root') {
            if (!$mysql->query("
              CREATE USER IF NOT EXISTS ". $mysql->real_escape_string($argv[2]) ." IDENTIFIED BY PASSWORD;
              GRANT ALL PRIVILEGES ON ". $mysql->real_escape_string($argv[2]) .".* TO '". $mysql->real_escape_string($argv[4]) ."'@'%' IDENTIFIED BY 'password';
            ")) {
              file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
              $mysql->close();
              exit(1);
            }
          }

          $mysql->close();
        ?>
EOPHP

      php maintenance/install.php \
        --quiet \
        --pass password \
        --scriptpath /wiki \
        --dbname ${WIKI_DB_NAME} \
        --dbserver ${MYSQL_PORT_3306_TCP_ADDR} \
        --dbuser ${WIKI_DB_USER} \
        --dbpass ${WIKI_DB_PW} \
        ${WIKI_SITE_NAME} admin 2> /dev/null
    else
      echo 'DB installation was skipped!'

      sed -i -e 's/{{WIKI_NAME}}/'${WIKI_SITE_NAME}'/' LocalSettings.php
      sed -i -e 's/{{MYSQL_SERVER}}/'${MYSQL_PORT_3306_TCP_ADDR}'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_NAME}}/'${WIKI_DB_NAME}'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_USER}}/'${WIKI_DB_USER}'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_PW}}/'${WIKI_DB_PW}'/' LocalSettings.php
  fi

  if [ -n "${WIKI_EXTRA_EXPOSED_PORT+1}" ]; then
    WIKI_SERVER_NAME="${WIKI_SERVER_NAME}:${WIKI_EXTRA_EXPOSED_PORT}"
  fi
  sed -i -e 's/\$wgServer = .*/\$wgServer = "http:\/\/'${WIKI_SERVER_NAME}'";/' LocalSettings.php

  echo "\$wgArticlePath = '/wiki/\$1';" >> LocalSettings.php
  echo "\$wgUsePathInfo = true;" >> LocalSettings.php

  chown -R www-data:www-data .
  chmod -R 744 images

  touch ./.installed
  echo 'installation has been completed!'
  fi

  exec $@
