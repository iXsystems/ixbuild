#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import PUT, GET_OUTPUT, setup_ssh_agent


class ssh_test(unittest.TestCase):

    def test_1_Configuring_SSH_Settings(self):
        payload = {"ssh_rootlogin": 'true'}
        assert PUT("/services/ssh/", payload) == 200

    def test_2_Enabling_SSH_Service(self):
        payload = {"srv_enable": 'true'}
        assert PUT("/services/services/ssh/", payload) == 200

    def test_3_Checking_SSH_enabled(self):
        assert GET_OUTPUT("/services/services/ssh/",'srv_state') == "RUNNING"

    def test_4_Start_local_SSH_Agent(self):
        assert setup_ssh_agent() == True



if __name__ == "__main__":
    unittest.main(verbosity=2)
