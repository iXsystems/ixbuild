#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD
# Location for tests into REST API of FreeNAS

import unittest
from functions import PUT, POST, GET_OUTPUT


class jails_test(unittest.TestCase):

    def test_01_Configuring_jails(self):
        payload = {"jc_ipv4_network_start": JAILIP,
                   "jc_path": "/mnt/tank/jails" }
        assert PUT("/jails/configuration/", payload) == 201
        # Timeout if jail creation hangs
  .     #${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass} -m 1200

    def test_02_Creating_jail_VNET_OFF(self):
        payload == {"jail_host": "testjail",
                    "jail_defaultrouter_ipv4": JAILGW,
                    "jail_ipv4": JAILIP,
                    "jail_ipv4_netmask": JAILNETMASK,
                    "jail_vnet": "false"}
        assert POST("/jails/jails/", payload) == 201

        # Remove timeout for other tests
  .     # ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

    def test_03_Mount_tank_share_into_jail(self):
        payload == {"destination": "/mnt",
                     "jail": "testjail",
                     "mounted": "true",
                     "readonly": "false",
                     "source": "/mnt/tank/share"}
        assert POST("/jails/mountpoints/", payload) == 201

    def test_04_Starting_jail(self):
        assert POST("/jails/jails/1/start/", "") == 202

    def test_05_Restarting_jail(self):
        assert POST("/jails/jails/1/restart/", "") == 202

    def test_06_Stopping_jail(self):
        assert POST("/jails/jails/1/stop/", "") == 202

if __name__ == "__main__":
    unittest.main(verbosity=2)
