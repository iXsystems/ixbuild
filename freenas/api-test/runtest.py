#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

from subprocess import call
from sys import argv
from os import path, remove, getcwd
import getopt

results_xml = getcwd() + '/results/'
localHome = path.expanduser('~')
keyPath = localHome + '/.ssh/test_id_rsa'

error_msg = """Usage for %s:
    --ip <###.###.###.###>     - IP of the FreeNAS
    --password <root password> - Password of the FreeNAS root user
    --interface <interface>    - The interface that FreeNAS is run one
    """ % argv[0]

# if have no argumment stop
if len(argv) == 1:
    print(error_msg)
    exit()

# look if all the argument are there.
try:
    myopts, args = getopt.getopt(argv[1:], 'ipI', ["ip=",
        "password=","interface="])
except getopt.GetoptError as e:
    print (str(e))
    print(error_msg)
    exit()

for output, arg in myopts:
    if output in ('-i', '--ip'):
        ip = arg
    elif output in ('-p', '--password'):
        passwd = arg
    elif output in ('-I', '--interface'):
        interface = arg

cfg_content = """#!/usr/bin/env python3.6

import os

user = "root"
password = "%s"
ip = "%s"
freenas_url = 'http://' + ip + '/api/v1.0'
interface = "%s"
ntpServer = "10.20.20.122"
localHome = "%s"
disk1 = "ada1"
disk2 = "ada2"
keyPath = "%s"
""" % (passwd, ip, interface, localHome, keyPath)

cfg_file = open("config.py", 'w')
cfg_file.writelines(cfg_content)
cfg_file.close()

from functions import setup_ssh_agent, create_key, add_ssh_key

# Setup ssh agent befor starting test.
setup_ssh_agent()
if path.exists(keyPath) is False:
    create_key(keyPath)
add_ssh_key(keyPath)

f = open(keyPath +'.pub', 'r')
Key = f.readlines()[0].rstrip()

cfg_file = open("config.py", 'a')
cfg_file.writelines('sshKey = "%s"\n' % Key)
cfg_file.close()

call(["py.test-3.6", "--junitxml", "%snetwork_result.xml" % results_xml, "network.py"])
call(["py.test-3.6", "--junitxml", "%sssh_result.xml" % results_xml, "ssh.py"])
call(["py.test-3.6", "--junitxml", "%sstorage_result.xml" % results_xml, "storage.py"])
