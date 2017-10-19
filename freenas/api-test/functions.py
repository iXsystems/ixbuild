#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import requests
from config import freenas_url, password, user
import json
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




