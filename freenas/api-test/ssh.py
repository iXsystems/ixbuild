#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import PUT, GET

class ssh_test(unittest.TestCase):
    @classmethod
    def setUpClass(inst):
        pass

    def test_1_Configuring_SSH_Settings(self):
        payload = {"ssh_rootlogin": 'true'}
        assert PUT("/services/ssh/", payload) == 200

    def test_2_Enabling_SSH_Service(self):
        payload = {"srv_enable": 'true'}
        assert PUT("/services/services/ssh/", payload) == 200

    def test_3_Checking_SSH_enabled(self):
        assert GET("/services/services/ssh/")


    @classmethod
    def tearDownClass(inst):
        pass

if __name__ == "__main__":
    unittest.main(verbosity=2)
