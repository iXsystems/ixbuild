# Author: Rishabh Chauhan
# License: BSD
# Location for tests  of FreeNAS new GUI

from source import * 
from selenium.webdriver.common.keys import Keys
from selenium import webdriver
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.by import By
from selenium.common.exceptions import ElementNotVisibleException
from selenium.common.exceptions import NoSuchElementException
import unittest

xpaths = { 'usernameTxtBox' : "//input[@id='inputUsername']",
	   'passwordTxtBox' : "//input[@id='inputPassword3']",
	  'submitButton' : "/html/body/app/main/login/div/div/form/div[3]/div[1]/button"
 	}

class Freenasui(unittest.TestCase):
  @classmethod
  def setUpClass(inst):
    #create a new Firefox session
    inst.driver = webdriver.Firefox()
    inst.driver.implicitly_wait(30)
    inst.driver.maximize_window()
    inst.driver.get(baseurl())



  def test_login(self):
    #enter username in the username textbox
    #self.driver.find_element_by_xpath(xpaths['usernameTxtBox']).send_keys("root")
    #enter password in the password textbox
    self.driver.find_element_by_xpath(xpaths['passwordTxtBox']).send_keys(password())
    #click
    self.driver.find_element_by_xpath("/html/body/app/main/login/div/div/form/div[3]/div[1]/button").click()

  def test_login_successful(self):
    #check if the dahsboard opens
    self.assertTrue(self.is_element_present(By.XPATH,"/html/body/app/main/pages/div/div/ba-content-top/header/div/div/h1"),"Unsuccessful Login")

  #method to test if an element is present
  def is_element_present(self, how, what):
    """
    Helper method to confirm the presence of an element on page
    :params how: By locator type
    :params what: locator value
    """
    try: self.driver.find_element(by=how, value=what)
    except NoSuchElementException: return False
    return True

  @classmethod
  def tearDownClass(inst):
    inst.driver.close()


if __name__ == "__main__":
  unittest.main(verbosity=2)
