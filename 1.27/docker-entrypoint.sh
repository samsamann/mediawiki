#!/bin/bash

: ${WIKI_SITE_NAME:=MediaWiki}
: ${WIKI_DNS_NAME:=localhost}
: ${WIKI_DB_NAME:=wiki}
: ${WIKI_DB_USER:=root}
: ${WIKI_DB_ALIAS:=wikidb}

ping -qc 3 ${WIKI_DB_ALIAS} &> /dev/null
if [[ $? -ne 0 && -z "$MYSQL_PORT_3306_TCP" ]]; then
	echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable.'
	echo >&2 'Did you forget to --link some_mysql_container:mysql ?'
  echo >&2 'Or did you forget to add alias "'${WIKI_DB_ALIAS}'" ?'
	exit 1
fi

# set DB address
WIKI_DB_ADDR=${WIKI_DB_ALIAS}
if [[ -n "$MYSQL_PORT_3306_TCP" ]]; then
  WIKI_DB_ADDR=${MYSQL_PORT_3306_TCP_ADDR}
fi

if [[ -z "$WIKI_DB_PW" && -n "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ]]; then
  WIKI_DB_PW=${MYSQL_ENV_MYSQL_ROOT_PASSWORD}
elif [[ -z "$WIKI_DB_PW" ]]; then
  echo >&2 'error: missing WIKI_DB_PW environment variable.'
  exit 1
fi

# installation mode
if [[ ! -f ./wiki/.installed ]]; then
  cd wiki
  if [[ -z "$WIKI_SKIP_DB" ]]; then
      #create new LocalSettings.php
      rm LocalSettings.php

      #create database
      TERM=dumb php -- "$WIKI_DB_ADDR" "$WIKI_DB_USER" "$WIKI_DB_PW" "$WIKI_DB_NAME" <<'EOPHP'
        <?php
          $mysql = new mysqli($argv[1], $argv[2], $argv[3], '', 3306);
          if ($mysql->connect_error) {
            file_put_contents('php://stderr', 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
            exit(1);
          }
          if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
            file_put_contents('php://stderr', 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
            $mysql->close();
            exit(1);
          }

          $mysql->close();
        ?>
EOPHP

      php maintenance/install.php \
        --quiet \
        --pass password \
        --scriptpath /wiki \
        --dbname ${WIKI_DB_NAME} \
        --dbserver ${WIKI_DB_ADDR} \
        --dbuser ${WIKI_DB_USER} \
        --dbpass ${WIKI_DB_PW} \
        ${WIKI_SITE_NAME} admin 2> /dev/null
    else
      echo 'DB installation was skipped!'

      sed -i -e 's/{{WIKI_NAME}}/'"${WIKI_SITE_NAME}"'/' LocalSettings.php
      sed -i -e 's/{{MYSQL_SERVER}}/'"${WIKI_DB_ADDR}"'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_NAME}}/'"${WIKI_DB_NAME}"'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_USER}}/'"${WIKI_DB_USER}"'/' LocalSettings.php
      sed -i -e 's/{{WIKI_DB_PW}}/'"${WIKI_DB_PW}"'/' LocalSettings.php
  fi

  if [[ -n "$WIKI_EXTRA_EXPOSED_PORT" ]]; then
    WIKI_DNS_NAME="${WIKI_DNS_NAME}:${WIKI_EXTRA_EXPOSED_PORT}"
  fi
  sed -i -e 's/\$wgServer = .*/\$wgServer = "http:\/\/'"${WIKI_DNS_NAME}"'";/' LocalSettings.php

  echo '$wgArticlePath = "/wiki/$1";' >> LocalSettings.php
  echo '$wgUsePathInfo = true;' >> LocalSettings.php

  chown -R www-data:www-data .
  chmod -R 744 images

  touch ./.installed
  echo 'installation has been completed!'
  fi

  exec $@
