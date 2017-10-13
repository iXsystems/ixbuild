#!/usr/bin/env python

# Author: Eric Turgeon
# License: BSD

from subprocess import call
from config import results_xml

call(["py.test", "--junitxml", "%snetwork_result.xml" % results_xml, "network.py"])

