#!/bin/bash


while [[ $# > 1 ]]
do
key="$1"

case $key in
    -c|--config)
    CONFIG="$2"
    shift # past argument
    ;;
    -t|--test)
    TEST="$2"
    shift # past argument
    ;;
    # -e|--lib)
    # LIBPATH="$2"
    # shift # past argument
    # ;;
    # --default)
    # DEFAULT=YES
    # ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

PROCESS=()
FILES=${CONFIG}

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
EOL='\n'

bold=$(tput bold)
normal=$(tput sgr0)

printf "${RED}Hi, I'm Syncia and will help you take your backups correctly!${NC}\n"
printf "${BLUE}To disable a backup use '_' as a prefix!${NC}\n"
printf "\n"

# FILES="find _config -name "_*" -print0 | xargs -0 ls"
printf "Get the config(s): ${FILES}\n"
printf "Stores valid configurations for further usage\n"
for f in $FILES
do
  if [[ ${f##*/} != _* ]] ; #Ignore files starting with '_'
  then
    printf "${GREEN}${f##*/}: added to process list${NC}\n"
    PROCESS+=("$f")
    # take action on each file. $f store current file name
    # cat $f
  # else
  #   printf "${RED}${f##*/}: starts with '_', so won't be processed!${NC}\n"
  fi
done

printf "${bold}${#PROCESS[@]} ${normal}valid configurations were found\n\n"
# printf '%s\n' "${PROCESS[@]}"

init() {
  HTTPS=
  LOCAL_DIR=
  REMOTE_DIR=
  REMOTE_URL=
  EXCLUDE_GLOBAL=
  EXCLUDE=
  SUCCESS_SQL=
  CONFIGFILE=$1
  . $1
  LOCAL_DIR="data/${LOCAL_DIR}"
  LOCAL_BASE_DIR="${LOCAL_DIR}"
  mkdir -p ${LOCAL_DIR}
}

# Backup via lftp
backup() {
  # start=$(date -u +"%s")
  # . $1
  printf "\n${BLUE}Start file-backup for ${DOMAIN}${NC}\n"
  printf "Local directory: ${LOCAL_DIR}\n"

  if [ ! -z "$TEST" ]; then
    printf "THIS IS A TEST RUN WHICH LASTS ONLY 5 seconds!\n"
  fi

  EXCLUDE_ARG=$(exclude "$EXCLUDE" "$EXCLUDE_GLOBAL")

  if [ ! -z "$TEST" ]; then
    if [ "$(uname)" == "Darwin" ]; then
        TIMEOUT="gtimeout 5s"
    else
        TIMEOUT="timeout 5s"
    fi
  fi

  ${TIMEOUT} lftp -u ${USER},${PASS} ${HOST} << EOF
  set ssl:verify-certificate no
  mirror -e -c ${EXCLUDE_ARG} ${REMOTE_DIR} ${LOCAL_DIR} --log="${LOCAL_DIR}/lftp.log"
  bye
EOF

  printf "${BLUE}End backup for ${DOMAIN}${NC}\n"
}

create_dir() {
  printf "${LOCAL_DIR}\n"
  LOCAL_DIR="${LOCAL_DIR}/$(date +"%Y-%m-%d-%H-%M-%S")"
  mkdir ${LOCAL_DIR}
}

# get_dir() {
#   IFS= read -r -d $'\0' line < <(find ${LOCAL_DIR} -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\0' \
#     2>/dev/null | sort -z -n)
#   file="${line#* }"
#   printf "$file\n"
# }

remove_dirs() {
  printf "Remove old directories in ${LOCAL_BASE_DIR}\n"

  rm -r `ls -lt -d -1 $LOCAL_BASE_DIR/{*,.*} | tail -n +6`
  # rm `ls -t ${LOCAL_BASE_DIR} | tail -n +6`
  # printf "${LOCAL_DIR}\n"
  # cd ${LOCAL_DIR}
  # (ls -tr | head -n 5;ls) | sort | uniq -u | sed -e 's,.*,"&",g' | xargs rm -rf
}
# flush_dir() {
#
# }

sendmail() {
  printf "Send mail to ${EMAIL}\n"
  if [ ! -z "$EMAIL" ];
  then
    CONFIGFILE_NAME=$(echo $CONFIGFILE | sed "s/.*\///")
    # if [ "$(uname)" == "Darwin" ]; then
    #   CONTENT_TYPE=
    # else
    #   CONTENT_TYPE=''
    # fi
    sed -e "s/\$FILENAME/$CONFIGFILE_NAME/g" -e "s/\$TIME/$2/g;s/\$PROJECT/$(echo $DOMAIN | sed -e 's/[\/&]/\\&/g')/" etc/message.html | mail -s "$(echo -e "Backup ${DOMAIN} ($CONFIGFILE_NAME)\nContent-Type: text/html")" ${EMAIL}
  fi
}

function join { perl -e '$s = shift @ARGV; print join($s, @ARGV);' "$@"; }

exclude() {

  IFS=' ' read -ra EXCLUDE_ARR <<< "$1"
  EXCLUDE_STR="-x $(join ' -x ' ${EXCLUDE_ARR[*]})"

  IFS=' ' read -ra EXCLUDE_GLOBAL_ARR <<< "$2"
  EXCLUDE_STR=$EXCLUDE_STR" -X $(join ' -X ' ${EXCLUDE_GLOBAL_ARR[*]})"

  echo ${EXCLUDE_STR}
}

sql_backup() {
  # . $1
  if [ "$HTTPS" = true ] ; then
    PROTOCOL="https"
    PORT=":443"
  else
    PROTOCOL="http"
    PORT=":80"
  fi
  DUMP_URL="$PROTOCOL://${DOMAIN}${PORT}${REMOTE_URL}/dump.php"
  # printf "${DUMP_URL}\n"

  create_sql_file $1
  put_sql $1
  call_url $DUMP_URL
  get_sql $1
}

# Create SQL file from template
# Replace tokens
create_sql_file() {
  printf "START - Create SQL file from template in ${LOCAL_DIR}/dump.php\n"
  # . $1
  # printf "Host: ${DB_HOST}\n"
  # printf "Name: ${DB_NAME}\n"
  # printf "User: ${DB_USER}\n"
  # printf "Pass: ${DB_PASS}\n"

  sed -e s/\$DB_HOST/${DB_HOST}/g -e s/\$DB_NAME/${DB_NAME}/g -e s/\$DB_USER/${DB_USER}/g -e s/\$DB_PASS/${DB_PASS}/g -e s/\$DB_PORT/${DB_PORT}/g etc/dump.tmpl.php > ${LOCAL_DIR}/dump.php
  printf "END - Create SQL file from template\n"
}

# Upload prepared SQL file onto server
# Remove it from local FS
put_sql() {
  # . $1
  lftp -u ${USER},${PASS} ${HOST} << EOF
  set ssl:verify-certificate no
  put -O ${REMOTE_DIR} ${LOCAL_DIR}/dump.php
  bye
EOF
}

call_url() {
  printf "Call remote URL ${1}\n"
  __wget $1
}

get_sql() {
  printf "Store file to local FS\n"
  lftp -u ${USER},${PASS} ${HOST} << EOF
  set ssl:verify-certificate no
  get -c ${REMOTE_DIR}dump.sql -o ${LOCAL_DIR}/dump.sql
  bye
EOF
}

# remove_sql() {
#   printf "Remove remote file\n"
#   . $1
#   lftp -u ${USER},${PASS} ${HOST} << EOF
#   rm ${REMOTE_DIR}/dump.sql ${REMOTE_DIR}/dump.php
#   bye
# EOF
# }

remove_traces () {
  # . $1
  rm ${LOCAL_DIR}/dump.php
  lftp -u ${USER},${PASS} ${HOST} << EOF
  set ssl:verify-certificate no
  rm ${REMOTE_DIR}/dump.sql ${REMOTE_DIR}/dump.php
  bye
EOF
  # remove_sql $1
}

zip() {
  printf "ZIP: ${LOCAL_DIR}\n"
  printf "Archive: $(basename $LOCAL_DIR)\n"
  ARCHIVE=$(basename $LOCAL_DIR).tar.gz
  tar -zcf ${LOCAL_BASE_DIR}${ARCHIVE} $LOCAL_DIR
}

function __wget() {
  : ${DEBUG:=0}
  local URL=$1
  local tag="Connection: close"
  local mark=0

  if [ -z "${URL}" ]; then
      printf "Usage: %s \"URL\" [e.g.: %s http://www.google.com/]" \
             "${FUNCNAME[0]}" "${FUNCNAME[0]}"
      return 1;
  fi
  read proto server path <<<$(echo ${URL//// })
  DOC=/${path// //}
  HOST2=${server//:*}
  PORT=${server//*:}
  [[ x"${HOST2}" == x"${PORT}" ]] && PORT=80
  [[ $DEBUG -eq 1 ]] && echo "HOST=$HOST2"
  [[ $DEBUG -eq 1 ]] && echo "PORT=$PORT"
  [[ $DEBUG -eq 1 ]] && echo "DOC =$DOC"

  exec 3<>/dev/tcp/${HOST2}/$PORT
  echo -en "GET ${DOC} HTTP/1.1\r\nHost: ${HOST2}\r\n${tag}\r\n\r\n" >&3
  while read line; do
      [[ $mark -eq 1 ]] && echo $line
      if [[ "${line}" =~ "${tag}" ]]; then
          mark=1
      fi
  done <&3
  exec 3>&-
}

printf "${GREEN}Process all valid configurations${NC}\n"
for p in "${PROCESS[@]}"
do
  start=$(date -u +"%s")

  init $p
  remove_dirs
  create_dir

  sql_backup $p
  backup $p
  remove_traces $p

  # zip it up
  zip

  stop=$(date -u +"%s")
  diff=$(($stop-$start))
  diff_string="$(($diff / 60)) minutes and $(($diff % 60)) seconds"
  sendmail $p "$diff_string"

  # exit
done
