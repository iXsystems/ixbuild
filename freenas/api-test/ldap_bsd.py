#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD
# Location for tests into REST API of FreeNAS

import unittest
from functions import PUT, POST, GET_OUTPUT


class iscsi_test(unittest.TestCase):

    def Clean_up_any_leftover_items(self):
        payload = { "ad_bindpw": ADPASSWORD,
                    "ad_bindname": ADUSERNAME,
                    "ad_domainname": BRIDGEDOMAIN,
                    "ad_netbiosname_a": BRIDGEHOST,
                    "ad_idmap_backend": "rid",
                    "ad_enable":"false" }
        PUT("/directoryservice/activedirectory/1/", payload)
        payload1 = {"ldap_basedn": LDAPBASEDN,
                    "ldap_anonbind": "true",
                    "ldap_netbiosname_a": BRIDGEHOST,
                    "ldap_hostname": LDAPHOSTNAME,
                    "ldap_has_samba_schema": "true",
                    "ldap_enable": "false" }
        PUT("/directoryservice/ldap/1/", payload1)
        PUT("/services/services/cifs/", {"srv_enable": "false"})
        payload2 = {"cfs_comment": "My Test SMB Share",
                    "cifs_path": SMB_PATH,
                    "cifs_name": SMB_NAME,
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr"}
        DELETE("/sharing/cifs/", payload2)
        DELETE("/storage/volume/1/datasets/%s/" % DATASET)
        #bsd_test "umount -f \"${MOUNTPOINT}\" &>/dev/null; rmdir \"${MOUNTPOINT}\" &>/dev/null"

    # Set auxilary parameters to allow mount_smbfs to work with ldap
    def test_02_Setting_auxilary_parameters_for_mount_smbfs(self):
        payload = { "cifs_srv_smb_options": "lanman auth = yes\nntlm auth = yes \nraw NTLMv2 auth = yes" }
        assert PUT("/services/cifs/", payload) == 200

    def test_03_Creating_SMB_dataset(self):
        assert POST("/storage/volume/tank/datasets/", {"name": DATASET}) == 201

    # Enable LDAP
    def test_04_Enabling_LDAP_with_anonymous_bind(self):
        payload = { "ldap_basedn": LDAPBASEDN,
                    "ldap_anonbind": "true",
                    "ldap_netbiosname_a": BRIDGEHOST,
                    "ldap_hostname": LDAPHOSTNAME,
                    "ldap_has_samba_schema": "true",
                    "ldap_enable": "true"}
        assert PUT("/directoryservice/ldap/1/", payload) == 200

    # Check LDAP
    def test_05_Checking_LDAP(self):
        assert GET_OUTPUT("/directoryservice/ldap/", "ldap_enable") == True

    def test_06_Enabling_SMB_service(self):
        payload = { "cifs_srv_description": "Test FreeNAS Server",
                    "cifs_srv_guest": "nobody",
                    "cifs_hostname_lookup": "false",
                    "cifs_srv_aio_enable": "false" }
        assert PUT("/services/cifs/", payload) == 200

    # Now start the service
    def test_07_Starting_SMB_service(self):
        assert PUT("/services/services/cifs/", {"srv_enable": "true"}) == 200

    def test_08_Checking_to_see_if_SMB_service_is_enabled(self):
        assert GET_OUTPUT("/services/services/cifs/", "srv_state") == "RUNNING"

    # Now check if we can mount SMB / create / rename / copy / delete / umount
    #echo_test_title "Poll VM to ensure SMB service is up and running"
    #wait_for_avail_port "445"
    #check_exit_status || return 1

    def test_09_Changing_permissions_on_SMB_PATH(self):
        payload = { "mp_path": SMB_PATH,
                    "mp_acl": "unix",
                    "mp_mode": "777",
                    "mp_user": "root",
                    "mp_group": "qa",
                    "mp_recursive": "true" }
        assert PUT("/storage/permission/", payload) == 201

    def test_10_Creating_a_SMB_share_on_SMB_PATH(self):
        payload = { "cfs_comment": "My Test SMB Share",
                    "cifs_path": SMB_PATH,
                    "cifs_name": SMB_NAME,
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr" }
        assert POST("/sharing/cifs/", payload) == 201

    #def test_11_Creating_SMB_mountpoint(self):
    #    bsd_test "mkdir -p '${MOUNTPOINT}' && sync"
    #    check_exit_status || return 1

    #sleep 10

    # The LDAPUSER user must exist in LDAP with this password
    #echo_test_title "Store LDAP credentials for mount_smbfs."
    #bsd_test "echo \"[TESTNAS:LDAPUSER]\" > ~/.nsmbrc && echo password=12345678 >> ~/.nsmbrc"
    #check_exit_status || return 1

    #echo_test_title "Mounting SMB"
    #bsd_test "mount_smbfs -N -I ${BRIDGEIP} -W LDAP01 //ldapuser@testnas/${SMB_NAME} '${MOUNTPOINT}'"
    #check_exit_status || return 1

    #echo_test_title "Verify SMB share has finished mounting"
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
    #bsd_test "rm '${MOUNTPOINT}/testfile2'"
    #check_exit_status || return 1

    #echo_test_title "Unmounting SMB"
    #bsd_test "umount -f \"${MOUNTPOINT}\""
    #check_exit_status || return 1

    #echo_test_title "Verifying SMB share was unmounted"
    #bsd_test "mount | grep -qv \"${MOUNTPOINT}\""
    #check_exit_status

    #echo_test_title "Removing SMB mountpoint"
    #bsd_test "test -d \"${MOUNTPOINT}\" && rmdir \"${MOUNTPOINT}\" || exit 0"
    #check_exit_status || return 1

    def test_24_Removing_SMB_share_on_SMB_PATH(self):
        payload = { "cfs_comment": "My Test SMB Share",
                    "cifs_path": SMB_PATH,
                    "cifs_name": SMB_NAME,
                    "cifs_guestok": "true",
                    "cifs_vfsobjects": "streams_xattr" }
        DELETE("/sharing/cifs/") == 204

    # Disable LDAP
    def test_25_Disabling_LDAP_with_anonymous_bind(self):
        payload = { "ldap_basedn": LDAPBASEDN,
                    "ldap_anonbind": true,
                    "ldap_netbiosname_a": "'${BRIDGEHOST}'",
                    "ldap_hostname": "'${LDAPHOSTNAME}'",
                    "ldap_has_samba_schema": true,
                    "ldap_enable": false }
        assert PUT("/directoryservice/ldap/1/", payload) == 200

    # Now stop the SMB service
    def test_26_Stopping_SMB_service(self):
        PUT("/services/services/cifs/", {"srv_enable": false}) == 200

    # Check LDAP
    def test_27_Verify_LDAP_is_disabled(self):
        GET_OUTPUT("/directoryservice/ldap/", "ldap_enable") == False

    def test_28_Verify_SMB_service_is_disabled(self):
        GET_OUTPUT("/services/services/cifs/") == "STOPPED"

    # Check destroying a SMB dataset
    def test_29_Destroying_SMB_dataset(self):
        DELETE("/storage/volume/1/datasets/%s/" % DATASET ) == 204


if __name__ == "__main__":
    unittest.main(verbosity=2)
