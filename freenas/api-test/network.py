#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

#Test case count: 1

import requests
from config import freenas_url, password, user, interface
import unittest
import json

class network(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        global header
        header = {'Content-Type': 'application/json', 'Vary': 'accept'}
        global payload
        payload = { "int_dhcp": 'true',
                    "int_name": "ext",
                    "int_interface": interface}
        global authentification
        authentification = (user, password)

    def test_1_configure_interface_dhcp(self):
        self.posttest = requests.post(freenas_url + '/network/interface/', headers=header,
                                      auth=authentification,
                                      data=json.dumps(payload))
        self.response = self.posttest.status_code
        assert self.response == 201

    @classmethod
    def tearDownClass(inst):
        pass

if __name__ == "__main__":
    unittest.main(verbosity=2)
