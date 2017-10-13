#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import requests
from config import freenas_url, ip_domain



def add_freenas_ip_to_dataset():
    posttest = requests.post(freenas_url + 'network/interface/',
                             data = {"int_ipv4address": ip_domain,
                                     "int_name": "int",
                                     "int_v4netmaskbit": "24",
                                     "int_interface": "em0"})
    response = posttest.status_code
    print(response)
    #assert response == 200

add_freenas_ip_to_dataset()

