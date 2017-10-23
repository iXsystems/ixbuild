#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import PUT, GET, POST
from config import disk1, disk2


class storage_test(unittest.TestCase):

    def test_1_Check_getting_disks(self):
        assert GET("/storage/disk/") == 200

    def test_2_Check_getting_disks(self):
        assert GET("/storage/volume/") == 200

    def test_3_Check_creating_a_zpool(self):
        payload = {"volume_name": "tank",
                   "layout": [{"vdevtype": "sripe", "disks": [disk1, disk2]}]}
        assert POST("/storage/volume/", payload) == 201

    def test_4_Check_creating_dataset_01_20_share(self):
        payload = {"name": "share"}
        assert POST("/storage/volume/tank/datasets/",payload) == 201

    def test_5_Check_creating_dataset_02_20_jails(self):
        payload = {"name": "jails"}
        assert POST("/storage/volume/tank/datasets/",payload) == 201

    def test_6_Changing_permissions_on_share(self):
        payload = {"mp_path": "/mnt/tank/share",
                   "mp_acl": "unix",
                   "mp_mode": "777",
                   "mp_user": "root",
                   "mp_group": "wheel"}
        assert PUT("/storage/permission/",payload) == 201

    def test_7_Changing_permissions_on_share(self):
        payload = {"mp_path": "/mnt/tank/jails",
                   "mp_acl": "unix",
                   "mp_mode": "777",
                   "mp_user": "root",
                   "mp_group": "wheel"}
        assert PUT("/storage/permission/", payload) == 201


if __name__ == "__main__":
    unittest.main(verbosity=2)
