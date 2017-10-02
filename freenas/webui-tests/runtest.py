from login import *
from subprocess import call
from os import path

#starting the test and genewratinf result
call(["py.test", "--junitxml", "/temp/result.xml", "login.py"])

#cleaning up files
if path.exists('login.pyc'):
    call(["rm", "login.pyc"])
if path.exists('source.pyc'):
    call(["rm", "source.pyc"])
if path.exists('__pycache__'):
    call(["rm", "-r", "__pycache__"])
if path.isdir('.cache'):
    call(["rm", "-r", ".cache"])
