#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

from auto_config import interface
from functions import POST
import unittest

class network(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        pass

    def test_1_configure_interface_dhcp(self):
        payload = {"int_dhcp": 'true',
                   "int_name": "ext",
                   "int_interface": interface
                  }
        assert POST("/network/interface/", payload) == 201

    @classmethod
    def tearDownClass(inst):
        pass

if __name__ == "__main__":
    unittest.main(verbosity=2)
