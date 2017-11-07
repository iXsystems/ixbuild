#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

import unittest
from functions import POST, GET_OUTPUT

DATASET="ad-osx"
SMB_NAME="TestShare"
SMB_PATH="/mnt/tank/${DATASET}"
MOUNTPOINT="/tmp/ad-osx${BRIDGEHOST}"
VOL_GROUP="qa"

class ad_osx_test(unittest.TestCase):

    # Clean up any leftover items from previous failed AD LDAP or SMB runs
    def test_01_Clean_up_any_leftover_items(self):
        payload1 = {"ad_bindpw": ADPASSWORD,
                    "ad_bindname": ADUSERNAME,
                    "ad_domainname": BRIDGEDOMAIN,
                    "ad_netbiosname_a": BRIDGEHOST,
                    "ad_idmap_backend": "rid",
                    "ad_enable":"false"}
        PUT("/directoryservice/activedirectory/1/", payload1)
        payload2 = {"ldap_basedn": LDAPBASEDN,
                    "ldap_binddn": LDAPBINDDN,
                    "ldap_bindpw": LDAPBINDPASSWORD,
                    "ldap_netbiosname_a": BRIDGEHOST,
                    "ldap_hostname": LDAPHOSTNAME,
                    "ldap_has_samba_schema": "true",
                    "ldap_enable": "false"}
        PUT("/directoryservice/ldap/1/", payload2)
        PUT("/services/services/cifs/", {"srv_enable": "false"})
        payload3 = {"cfs_comment": "My Test SMB Share",
                    "cifs_path": SMB_PATH,
                    "cifs_name": SMB_NAME,
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr" }
        DELETE_ALL("/sharing/cifs/", payload3)
        DELETE("/storage/volume/1/datasets/%s/" % DATASET)

    # Set auxilary parameters to allow mount_smbfs to work with Active Directory
    def test_02_Creating_SMB_dataset(self):
        assert POST("/storage/volume/tank/datasets/", {"name": DATASET}) == 201

    def test_03_Enabling_Active_Directory(self):
        payload = { "ad_bindpw": ADPASSWORD,
                    "ad_bindname": ADUSERNAME,
                    "ad_domainname": BRIDGEDOMAIN,
                    "ad_netbiosname_a": BRIDGEHOST,
                    "ad_idmap_backend": "rid",
                    "ad_enable":"true" }
        assert PUT("/directoryservice/activedirectory/1/",payload) == 200

    def test_04_Checking_Active_Directory(self):
        assert GET_OUTPUT("/directoryservice/activedirectory/", "ad_enable") == True

    def test_05_Checking_to_see_if_SMB_service_is_enabled(self):
        assert GET("/services/services/cifs/", "srv_state") == "RUNNING"

    def test_06_Enabling_SMB_service(self):
        payload = { "cifs_srv_description": "Test FreeNAS Server",
                    "cifs_srv_guest": "nobody",
                    "cifs_hostname_lookup": "false",
                    "cifs_srv_aio_enable": "false" }
        assert PUT("/services/cifs/", payload) ==  200

    # Now start the service
    def test_07_Starting_SMB_service(self):
        assert PUT("/services/services/cifs/", {"srv_enable": "true"}) == 200


if __name__ == "__main__":
    unittest.main(verbosity=2)

