from login import *
from subprocess import call

#starting the test and genewratinf result
call(["py.test", "--junitxml", "/temp/result.xml", "login.py"])

#cleaning up files
call(["rm", "login.pyc"])
call(["rm", "source.pyc"])
call(["rm", "-r", "__pycache__"])
call(["rm", "-r", ".cache"])
