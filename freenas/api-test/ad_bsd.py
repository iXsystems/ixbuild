#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD
# Location for tests into REST API of FreeNAS

import unittest
from functions import PUT, POST, GET_OUTPUT, DELETE

DATASET="ad-bsd"
SMB_NAME="TestShare"
SMB_PATH="/mnt/tank/${DATASET}"
MOUNTPOINT="/tmp/${BRIDGEHOST}ad-bsd"
VOL_GROUP="qa"

class ad_bsd_test(unittest.TestCase):
    def test_01_Clean_up_any_leftover_items(self):
        payload1 = {"ad_bindpw": ADPASSWORD,
                    "ad_bindname": ADUSERNAME,
                    "ad_domainname": BRIDGEDOMAIN,
                    "ad_netbiosname_a": BRIDGEHOST,
                    "ad_idmap_backend": "rid",
                    "ad_enable":"false" }
        PUT("/directoryservice/activedirectory/1/" payload1)
        payload2 = {"ldap_basedn": LDAPBASEDN,
                    "ldap_binddn": LDAPBINDDN},
                    "ldap_bindpw": LDAPBINDPASSWORD,
                    "ldap_netbiosname_a": BRIDGEHOST,
                    "ldap_hostname": LDAPHOSTNAME,
                    "ldap_has_samba_schema": "true",
                    "ldap_enable": "false"}
        PUT("/directoryservice/ldap/1/", payload2)
        PUT("/services/services/cifs/" {"srv_enable": false})
        payload3 = {"cfs_comment": "My Test SMB Share",
                    "cifs_path": "'"${SMB_PATH}"'",
                    "cifs_name": "'"${SMB_NAME}"'",
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr"}
        DELETE("/sharing/cifs/", payload3)
        DELETE("/storage/volume/1/datasets/${DATASET}/")
        #bsd_test "umount -f \"${MOUNTPOINT}\" &>/dev/null; rmdir \"${MOUNTPOINT}\" &>/dev/null"

    # Set auxilary parameters to allow mount_smbfs to work with Active Directory
    def test_02_Creating_SMB_dataset(self):
        assert POST("/storage/volume/tank/datasets/" { "name": DATASET}) == 201

    def Enabling_Active_Directory(self):
        payload = { "ad_bindpw": ADPASSWORD,
                    "ad_bindname": ADUSERNAME,
                    "ad_domainname": BRIDGEDOMAIN,
                    "ad_netbiosname_a": BRIDGEHOST,
                    "ad_idmap_backend": "rid",
                    "ad_enable":"true" }
        assert PUT("/directoryservice/activedirectory/1/", payload) == 200

    def test_04_Checking_Active_Directory(self):
        GET("/directoryservice/activedirectory/", "ad_enable") ==

    def test_05_Checking_to_see_if_SMB_service_is_enabled(self):
        assert GET_OUTPUT("/services/services/cifs/", "srv_state") == "RUNNING"


    def test_06_Enabling_SMB_service(self):
        payload = { "cifs_srv_description": "Test FreeNAS Server",
                    "cifs_srv_guest": "nobody",
                    "cifs_hostname_lookup": "false",
                    "cifs_srv_aio_enable": "false" }
        assert PUT("/services/cifs/",payload) == 200

    # Now start the service
    def test_07_Starting_SMB_service(self):
        PUT("/services/services/cifs/", {"srv_enable": "true"}) == 200

    #echo_test_title "Creating SMB mountpoint"
    #bsd_test "mkdir -p '${MOUNTPOINT}' && sync"
    #check_exit_status || return 1

    def test_08_Changing_permissions_on_SMB_PATH(self):
        payload = { "mp_path": SMB_PATH,
                    "mp_acl": "unix",
                    "mp_mode": "777", "mp_user":
                    "root", "mp_group": "AD01\\QA",
                    "mp_recursive": "true" }
        assert PUT("/storage/permission/", payload) == 201

    def test_09_Creating_a_SMB_share_on_SMB_PATH(self):
        payload = { "cfs_comment": "My Test SMB Share",
                    "cifs_path": SMB_PATH,
                    "cifs_name": SMB_NAME,
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr" }
        assert POST("/sharing/cifs/", payload) == 201

    #sleep 10

    # The ADUSER user must exist in AD with this password
    #echo_test_title "Store AD credentials in a file for mount_smbfs"
    #bsd_test "echo \"[TESTNAS:ADUSER]\" > ~/.nsmbrc && echo password=12345678 >> ~/.nsmbrc"
    #check_exit_status || return 1

    #echo_test_title "Mounting SMB"
    #bsd_test "mount_smbfs -N -I ${BRIDGEIP} -W AD01 \"//aduser@testnas/${SMB_NAME}\" \"${MOUNTPOINT}\""
    #check_exit_status || return 1

    #echo_test_title "Verify that SMB share has finished mounting"
    #wait_for_bsd_mnt "${MOUNTPOINT}"
    #check_exit_status || return 1

    #local device_name=`dirname "${MOUNTPOINT}"`
    #echo_test_title "Checking permissions on ${MOUNTPOINT}"
    #bsd_test "ls -la '${device_name}' | awk '\$4 == \"${VOL_GROUP}\" && \$9 == \"${DATASET}\" ' "
    #check_exit_status

    #echo_test_title "Creating SMB file"
    #bsd_test "touch '${MOUNTPOINT}/testfile'"
    #check_exit_status || return 1

    #echo_test_title "Moving SMB file"
    #bsd_test "mv '${MOUNTPOINT}/testfile' '${MOUNTPOINT}/testfile2'"
    #check_exit_status || return 1

    #echo_test_title "Copying SMB file"
    #bsd_test "cp '${MOUNTPOINT}/testfile2' '${MOUNTPOINT}/testfile'"
    #check_exit_status || return 1

    #echo_test_title "Deleting SMB file 1/2"
    #bsd_test "rm '${MOUNTPOINT}/testfile'"
    #check_exit_status || return 1

    #echo_test_title "Deleting SMB file 2/2"
    #bsd_test "rm \"${MOUNTPOINT}/testfile2\""
    #check_exit_status || return 1

    #echo_test_title "Unmounting SMB"
    #bsd_test "umount \"${MOUNTPOINT}\""
    #check_exit_status || return 1

    #echo_test_title "Removing SMB mountpoint"
    #bsd_test "test -d \"${MOUNTPOINT}\" && rmdir \"${MOUNTPOINT}\" || exit 0"
    #check_exit_status || return 1

    #echo_test_title "Removing SMB share on ${SMB_PATH}"
    #rest_request "DELETE" "/sharing/cifs/" '{ "cfs_comment": "My Test SMB Share", "cifs_path": "'"${SMB_PATH}"'", "cifs_name": "'"${SMB_NAME}"'", "cifs_guestok": true, "cifs_vfsobjects": "streams_xattr" }'
    #check_rest_response "204"

    # Disable Active Directory Directory
    def test_10_Disabling_Active_Directory(test):
        payload = { "ad_bindpw": "'${ADPASSWORD}'",
                "ad_bindname": "'${ADUSERNAME}'",
                "ad_domainname": "'${BRIDGEDOMAIN}'",
                "ad_netbiosname_a": "'${BRIDGEHOST}'",
                "ad_idmap_backend": "rid",
                "ad_enable":"false" }
        assert PUT("/directoryservice/activedirectory/1/", payload) == 200

    # Check Active Directory
    def test_11_Verify_Active_Directory_is_disabled(self):
        GET_OUTPUT("/directoryservice/activedirectory/", "ad_enable") == False

    def test_12_Verify_SMB_service_is_disabled(self):
        assert GET_OUTPUT("/services/services/cifs/", "srv_state") == "STOPPED"

    # Check destroying a SMB dataset
    def test_14_Destroying_SMB_dataset(self):
        assert DELETE("/storage/volume/1/datasets/${DATASET}/") == 204


if __name__ == "__main__":
    unittest.main(verbosity=2)
