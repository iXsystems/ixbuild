#!/usr/bin/env python3.6

# Author: Eric Turgeon
# License: BSD

from subprocess import call
from sys import argv
from os import path, remove, getcwd
import getopt

results_xml = getcwd() + '/results/'

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

user = "root"
password = "%s"
ip = "%s"
freenas_url = 'http://' + ip + '/api/v1.0'
interface = "%s"
""" % (passwd, ip, interface )

cfg_file = open("config.py", 'w')
cfg_file.writelines(cfg_content)
cfg_file.close()
call(["py.test-3.6", "--junitxml", "%snetwork_result.xml" % results_xml, "network.py"])
call(["py.test-3.6", "--junitxml", "%sssh_result.xml" % results_xml, "ssh.py"])
#if path.exists('config.py'):
#    remove("config.py")
#if path.exists('config.pyc'):
#    remove("config.pyc")

