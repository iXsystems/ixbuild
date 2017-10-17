#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import requests
from config import freenas_url, ip_domain, password, user

IFACE="vtnet0"

session = requests.Session()
session.auth = (user,password)

def add_freenas_ip_to_dataset():
    posttest = session.post(freenas_url + 'network/interface/',
                             data={ "int_dhcp": 'true', "int_name": "ext",
                                 "int_interface": IFACE})
    response = posttest.status_code
    print(response)
    assert response == 201

add_freenas_ip_to_dataset()
