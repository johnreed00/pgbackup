#!/bin/bash

logx() {
  echo "$1" | logger -t pgbackup -p user.info
}

help() {
  echo "PostgreSQL database backup script"
  echo "Creates and validates database backups by pg_dump and gzip in the backup directory"
  echo "Set env variables: db connection (PGPASSWORD, PGUSER, PGHOST) and PGBACKUP_DIR, PGBACKUP_DATABASES"
  echo
  echo "Example:"
  echo "# export PGBACKUP_DIR=/backup # backup directory"
  echo "# export PGBACKUP_DATABASES='test0 test1 test2' # databases to backup"
  echo "# export PGPASSWORD=xxx # db connection"
  echo "# export PGUSER=postgres # db connection"
  echo "# export PGHOST=127.0.0.1 # db connection"
  echo
  echo "Run script:"
  echo "# ./$(basename $0)"
  echo
}

clean() {
  [ ! -z "$TMP_PGBACKUP_DIR" -a -d "$TMP_PGBACKUP_DIR" ] && rm -rf $TMP_PGBACKUP_DIR
}

errx() {
  logx "Error: $1"
  clean
  exit 1
}

action() {
  { $2 2>&1 | logger -t pgbackup -p user.info ; } || errx "$1 - failed"
  logx "$1 - OK"
}


while getopts "h" OPTION; do
  case $OPTION in
    h) help
    ;;
  esac
done

[ -z "$PGPASSWORD" ] && errx "PGPASSWORD is not defined"
[ -z "$PGUSER" ] && errx "PGUSER is not defined"
[ -z "$PGHOST" ] && errx "PGHOST is not defined"
[ -z "$PGBACKUP_DIR" ] && errx "PGBACKUP_DIR is not defined"
[ -z "$PGBACKUP_DATABASES" ] && errx "PGBACKUP_DATABASES is not defined"

PGBACKUP_DIR=$(realpath $PGBACKUP_DIR)
TMP_PGBACKUP_DIR=$PGBACKUP_DIR/tmp

logx "START"

action "create temporary directory" "mkdir -p $TMP_PGBACKUP_DIR"
cd $TMP_PGBACKUP_DIR/

set -o pipefail
for DB in $PGBACKUP_DATABASES
do
  action "pg_dump $DB database" "pg_dump -c -d $DB -f $DB.sql"
done

action "create archive" "tar zcf pgbackup.tgz *.sql"
action "archive integrity validation" "gzip -tv pgbackup.tgz"
action "move archive" "mv pgbackup.tgz $PGBACKUP_DIR/pgbackup-$(date +%d-%m-%Y.%H:%M:%S).tgz"
clean
logx "archive $PGBACKUP_DIR/pgbackup-$(date +%d-%m-%Y.%H:%M:%S).tgz created OK"
