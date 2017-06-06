#!/usr/bin/env bash
CURRDIR="$(realpath "$(dirname "$0")")"

source "${CURRDIR}/../../../build.conf"
if [ -f "${CURRDIR}/../config.local" ]; then
  source "${CURRDIR}/../config.local"
else
  source "${CURRDIR}/../config.prod"
fi

# BRIDGEIP = Bridged IP address for the FreeNAS/TrueNAS host (see ${CURRDIR}/../../../build.conf)

REQUIRED_SETTINGS=( "SELENIUMSERVER" "SELENIUMPORT" "BRIDGEIP" "ANGULAR_BASEURI" )
for SETTING in "${REQUIRED_SETTINGS[@]}"
do  
  if [ -z "${!SETTING}" ]; then
    echo "Required environment variable settings for angular test automation:"
    echo "'${REQUIRED_SETTINGS[*]}'; missing ${SETTING}"
    exit 1
  fi  
done

BASEURL="http://${BRIDGEIP}${ANGULAR_BASEURI}"
START_WEBDRIVER="false"

echo "Using --baseUrl=${BASEURL}"
if [ "$1" == "-s" ]; then
  START_WEBDRIVER="true"
  shift
fi

require_webdriver()
{
  # Make sure webdriver-manager is updated and running
  if which -s webdriver-manager; then
    local webdriver_status=$(webdriver-manager status)
    if echo $webdriver_status | grep -q "selenium"; then
      echo $webdriver_status
    else
      webdriver-manager update && nohup webdriver-manager start & disown
    fi
  fi

  webdriver-manager status | grep -q "selenium"
  return $?
}

runtests()
{
  protractor "${CURRDIR}/conf.js" \
    --browser=chrome \
    --seleniumAddress="http://${SELENIUMSERVER}:${SELENIUMPORT}/wd/hub" \
    --seleniumPort="${SELENIUMPORT}" \
    --baseUrl="${BASEURL}"
}

if [ "${START_WEBDRIVER}" == "true" ] ; then
  require_webdriver && runtests
else
  runtests
fi
