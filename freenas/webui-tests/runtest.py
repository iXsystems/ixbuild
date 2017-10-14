#/usr/bin/env python

from subprocess import call
from os import path


#starting the test and genewratinf result
call(["py.test", "--junitxml", "/temp/result.xml", "driver.py"])
# call driver.py with python
#call(["python", "driver.py"])

#cleaning up files
if path.exists('login.pyc'):
    call(["rm", "login.pyc"])

if path.exists('source.pyc'):
    call(["rm", "source.pyc"])

if path.exists('user.pyc'):
    call(["rm", "user.pyc"])

if path.exists('group.pyc'):
    call(["rm", "group.pyc"])

if path.exists('logout.pyc'):
    call(["rm", "logout.pyc"])

if path.exists('guide.pyc'):
    call(["rm", "guide.pyc"])

if path.exists('__pycache__'):
    call(["rm", "-r", "__pycache__"])

if path.isdir('.cache'):
    call(["rm", "-r", ".cache"])
