#!/bin/bash

DIR=/docker-entrypoint.d

BOLD="\033[1m"
RESET="\033[0m"
BLUE="\033[34m"

echo -e "${BOLD}Running all initialization scripts in ${DIR}..."
if [ -d "${DIR}" ]; then
  for f in ${DIR}/*; do
    case "$f" in
      *.sh)     echo -e "${RESET}${BOLD}$0: running $f${BLUE}"; . "$f" ;;
      *)        echo -e "${RESET}${BOLD}$0: ignoring $f${BLUE}" ;;
    esac
    echo
  done
  echo -e "${RESET}${BOLD}$0: done running all initialization scripts in ${DIR}."
else
  echo -e "${BOLD}$0: ${DIR} does not exist, skipping initialization scripts."
fi

echo -e "Starting Solr...${RESET}"