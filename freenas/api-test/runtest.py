#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

from subprocess import call
from config import results_xml
from sys import argv
import getopt

error_msg = """Usage for %s:
    -ip <###.###.###.###>     - IP of the FreeNAS
    -password <root password> - Password of the FreeNAS root user
    -interface <interface>    - The interface that FreeNAS is run one
    """ % argv[0]

# if have no argumment stop
if len(argv) == 1:
    print(error_msg)
    exit()

# look if all the argument are there.
try:
    myopts, args = getopt.getopt(argv[1:], "ip:password:interface")
except getopt.GetoptError as e:
    print (str(e))
    print(error_msg)
    exit()

for output, arg in myopts:
    if output == '-ip':
        ip = arg
    elif output == '-password':
        password = arg
    elif output == '-interface':
        interface = arg

cfg_content = """#!/usr/bin/env python

import os

results_xml = os.getcwd() + '/results/'
user = "root"
password = "%s"
ip_domain = "%s"
freenas_url = 'http://' + ip_domain + '/api/v1.0/'
interface = "%s"
""" % (password, ip, interface )

cfg_file = open("config.py", 'w')
cfg_file.writelines(cfg_content)
cfg_file.close()

call(["py.test", "--junitxml", "%snetwork_result.xml" % results_xml, "network.py"])

