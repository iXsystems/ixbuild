#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import requests
from config import freenas_url, password, user
import json
import os
from subprocess import run, PIPE
import logging
import re

global header
header = {'Content-Type': 'application/json', 'Vary': 'accept'}
global authentification
authentification = (user, password)

def GET(testpath):
    getit = requests.get(freenas_url + testpath, headers=header,
                         auth=authentification)
    return getit.status_code

def GET_OUTPUT(testpath, inputs):
    getit = requests.get(freenas_url + testpath, headers=header,
                         auth=authentification)
    return getit.json()[inputs]

def POST(testpath, payload):
    postit = requests.post(freenas_url + testpath, headers=header,
                           auth=authentification, data=json.dumps(payload))
    return postit.status_code

def PUT(testpath, payload):
    putit = requests.put(freenas_url + testpath, headers=header,
                         auth=authentification,
                         data=json.dumps(payload))
    return putit.status_code

def start_ssh_agent():
    process = run(['ssh-agent','-s'], stdout=PIPE, universal_newlines=True)
    OUTPUT_PATTERN = re.compile('SSH_AUTH_SOCK=(?P<socket>[^;]+).*SSH_AGENT_PID=(?P<pid>\d+)',
                                re.MULTILINE | re.DOTALL)
    match = OUTPUT_PATTERN.search(process.stdout)
    if match is None:
        return False
    else:
        agentData = match.groupdict()
        os.environ[ 'SSH_AUTH_SOCK' ] = agentData['socket']
        os.environ[ 'SSH_AGENT_PID' ] = agentData['pid']
        return True

def is_agent_setup():
    return os.environ.get( 'SSH_AUTH_SOCK' ) is not None

def setup_ssh_agent():
    if is_agent_setup():
        return True
    else:
        logging.info( 'ssh-agent not present, will now set it up' )
    return start_ssh_agent()


