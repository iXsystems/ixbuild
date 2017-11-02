#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD
# Location for tests into REST API of FreeNAS

import unittest
from functions import PUT, POST, GET_OUTPUT

NFS_PATH = "/mnt/tank/share"
MOUNTPOINT = "/tmp/%snfs" % BRIDGEHOST

class nfs_test(unittest.TestCase):

  # Enable NFS server
    def test_01_Creating_the_NFS_server(self):
        paylaod = { "nfs_srv_bindip": BRIDGEIP,
                    "nfs_srv_mountd_port": 618,
                    "nfs_srv_allow_nonroot": false,
                    "nfs_srv_servers": 10,
                    "nfs_srv_udp": false,
                    "nfs_srv_rpcstatd_port": 871,
                    "nfs_srv_rpclockd_port": 32803,
                    "nfs_srv_v4": false,
                    "nfs_srv_v4_krb": false,
                    "id": 1 }
        assert PUT("/services/nfs/", paylaod) == 200

    # Check creating a NFS share
    def test_02_Creating_a_NFS_share_on_NFS_PATH(self):
        paylaod = { "nfs_comment": "My Test Share",
                    "nfs_paths": [NFS_PATH],
                    "nfs_security": "sys" }
        assert POST("/sharing/nfs/", paylaod) == 201

    # Now start the service
    def test_03_Starting_NFS_service(self):
        assert PUT("/services/services/nfs/", {"srv_enable": true}) == 200

    #def test_04_Verify_that_nfsd_shows_up_in_netstat_results(self):
    #    ssh_test "netstat -lap tcp | grep nfsd | awk '\$6 == \"LISTEN\" || \$6 == \"ESTABLISHED\" '"


    #def test05 Verify NFS server on host"
    #wait_for_fnas_mnt "${NFS_PATH}" "Everyone"
    #check_exit_status || return 1

    def test_06_Checking_to_see_if_NFS_service_is_enabled(self):
        assert GET_OUTPUT("/services/services/nfs/", "srv_state") == "RUNNING"

    # Now check if we can mount NFS / create / rename / copy / delete / umount
    #def test_06_Creating_NFS_mountpoint(self):
    #    bsd_test "mkdir -p \"${MOUNTPOINT}\""
    #    check_exit_status || return 1

    #echo_test_title "Mounting NFS"
    #bsd_test "mount_nfs ${BRIDGEIP}:${NFS_PATH} ${MOUNTPOINT}" "umount '${MOUNTPOINT}' ; rmdir '${MOUNTPOINT}'" "60"
    #check_exit_status || return 1

    #echo_test_title "Creating NFS file"
    #bsd_test "touch '${MOUNTPOINT}/testfile'" "umount '${MOUNTPOINT}'; rmdir '${MOUNTPOINT}'"
    #check_exit_status || return 1

    #echo_test_title "Moving NFS file"
    #bsd_test "mv '${MOUNTPOINT}/testfile' '${MOUNTPOINT}/testfile2'"
    #check_exit_status || return 1

    #echo_test_title "Copying NFS file"
    #bsd_test "cp '${MOUNTPOINT}/testfile2' '${MOUNTPOINT}/testfile'"
    #check_exit_status || return 1

    #echo_test_title "Deleting NFS file"
    #bsd_test "rm '${MOUNTPOINT}/testfile2'"
    #check_exit_status || return 1

    #echo_test_title "Unmounting NFS"
    #bsd_test "umount '${MOUNTPOINT}'"
    #check_exit_status || return 1

    #echo_test_title "Removing NFS mountpoint"
    #bsd_test "test -d \"${MOUNTPOINT}\" && rmdir \"${MOUNTPOINT}\" || exit 0"
    #check_exit_status || return 1

if __name__ == "__main__":
    unittest.main(verbosity=2)
