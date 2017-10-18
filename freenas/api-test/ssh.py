#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import PUT

class ssh_test(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        pass

    def test_1_configuring_ssh_settings(self):
        payload = {"ssh_rootlogin": 'true'}
        assert PUT("/services/ssh/", payload) == 200

#    def test_2_enabling_ssh_service(self):
#        pass

    @classmethod
    def tearDownClass(inst):
        pass

if __name__ == "__main__":
    unittest.main(verbosity=2)
