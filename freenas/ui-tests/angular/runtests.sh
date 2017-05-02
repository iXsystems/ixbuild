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
echo "Using --baseUrl=${BASEURL}"

#**you must either specify a configuration file or at least 3 options. See below for the options:
#
#Usage: protractor [configFile] [options]
#configFile defaults to protractor.conf.js
#The [options] object will override values from the config file.
#See the reference config for a full list of options.
#
#Options:
#  --help                                 Print Protractor help menu                               
#  --version                              Print Protractor version                                 
#  --browser, --capabilities.browserName  Browsername, e.g. chrome or firefox                      
#  --seleniumAddress                      A running selenium address to use                        
#  --seleniumSessionId                    Attaching an existing session id                         
#  --seleniumServerJar                    Location of the standalone selenium jar file             
#  --seleniumPort                         Optional port for the selenium standalone server         
#  --baseUrl                              URL to prepend to all relative paths                     
#  --rootElement                          Element housing ng-app, if not html or body              
#  --specs                                Comma-separated list of files to test                    
#  --exclude                              Comma-separated list of files to exclude                 
#  --verbose                              Print full spec names                                    
#  --stackTrace                           Print stack trace on error                               
#  --params                               Param object to be passed to the tests                   
#  --framework                            Test framework to use: jasmine, mocha, or custom         
#  --resultJsonOutputFile                 Path to save JSON test result                            
#  --troubleshoot                         Turn on troubleshooting output                           
#  --elementExplorer                      Interactively test Protractor commands                   
#  --debuggerServerPort                   Start a debugger server at specified port instead of repl
#  --disableChecks                        disable cli checks      

protractor "${CURRDIR}/conf.js" \
  --browser=chrome \
  --seleniumAddress="http://${SELENIUMSERVER}:${SELENIUMPORT}/wd/hub" \
  --seleniumPort="${SELENIUMPORT}" \
  --rootElement=app \
  --baseUrl="${BASEURL}"
