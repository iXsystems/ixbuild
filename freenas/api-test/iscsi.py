#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD
# Location for tests into REST API of FreeNAS

import unittest
from functions import PUT, POST, GET_OUTPUT


class iscsi_test(unittest.TestCase):

    def test_01_Clean_up_any_leftover_items(self):
        payload = {"srv_enable": "false"}
        assert PUT("/services/services/iscsitarget/", payload) == 200

    def test_02_Add_ISCSI_portal(self):
        payload = {"iscsi_target_portal_ips": ["0.0.0.0:3620"]}
        assert POST("/services/iscsi/portal/", payload) == 201

    # Add iSCSI target
    def test_03_Add_ISCSI_target(self):
        payload = {"iscsi_target_name": TARGET_NAME}
        assert POST("/services/iscsi/target/", payload) == 201

    # Add Target to groups
    def test_04_Add_target_to_groups():
        payload = {"iscsi_target": "1",
                   "iscsi_target_authgroup": "null",
                   "iscsi_target_portalgroup": 1,
                   "iscsi_target_initiatorgroup": "1",
                   "iscsi_target_authtype": "None",
                   "iscsi_target_initialdigest": "Auto"}

        assert POST("/services/iscsi/targetgroup/", payload) == 201

    # Add iSCSI extent
    def test_05_Add_ISCSI_extent():
        payload = {"iscsi_target_extent_type": "File",
                   "iscsi_target_extent_name": "extent",
                   "iscsi_target_extent_filesize": "50MB",
                   "iscsi_target_extent_rpm": "SSD",
                   "iscsi_target_extent_path": "/mnt/tank/dataset03/iscsi"}
        assert POST("/services/iscsi/extent/", payload) == 201

    # Associate iSCSI target
    def test_06_Associate_ISCSI_target():
        payload = {"id": "1", "iscsi_extent": "1",
                   "iscsi_lunid": "null",
                   "iscsi_target": "1" }
        assert POST("/services/iscsi/targettoextent/", payload) == 201

    # Enable the iSCSI service
    def test_07_Enable_iSCSI_service():
        payload = {"srv_enable": "true"}
        assert PUT("/services/services/iscsitarget/", payload) == 200

    def test_08_Verify_the_iSCSI_service_is_enabled();
        assert GET_OUTPUT("/services/services/iscsitarget/", "srv_state") == "RUNNING"



if __name__ == "__main__":
    unittest.main(verbosity=2)
