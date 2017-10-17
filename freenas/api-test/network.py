#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

#Test case count: 1

import requests
from config import freenas_url, ip_domain, password, user, interface
import unittest

class network(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        inst.session = requests.Session()
        inst.session.auth = (user, password)

    def test_1_configure_interface_dhcp(self):
        self.posttest = self.session.post(freenas_url + 'network/interface/',
                             data={ "int_dhcp": 'true', "int_name": "ext",
                                 "int_interface": interface})
        self.response = self.posttest.status_code
        print(self.response)
        assert self.response == 201

    @classmethod
    def tearDownClass(inst):
        pass

if __name__ == "__main__":
    unittest.main(verbosity=2)
