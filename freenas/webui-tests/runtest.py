#/usr/bin/env python

from source import *
from login import run_login_test
from subprocess import call
from os import path
from selenium import webdriver
import unittest

#caps = webdriver.DesiredCapabilities().FIREFOX
#caps["marionette"] = False
#driver = webdriver.Firefox(capabilities=caps)
#driver.get(baseurl)




#starting the test and genewratinf result
#call(["py.test", "--junitxml", "/temp/result.xml", "login.py", session_id, executor_url])
suite = unittest.TestLoader().loadTestsFromTestCase(run_login_test)
unittest.TextTestRunner(verbosity=2).run(suite)


#cleaning up files
if path.exists('login.pyc'):
    call(["rm", "login.pyc"])
if path.exists('source.pyc'):
    call(["rm", "source.pyc"])
if path.exists('__pycache__'):
    call(["rm", "-r", "__pycache__"])
if path.isdir('.cache'):
    call(["rm", "-r", ".cache"])
