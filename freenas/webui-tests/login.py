# Author: Rishabh Chauhan
# License: BSD
# Location for tests  of FreeNAS new GUI
#Test case count: 2

from source import * 
from selenium.webdriver.common.keys import Keys
from selenium import webdriver
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.by import By
from selenium.common.exceptions import ElementNotVisibleException
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains


import time
import unittest
import random
try:
    import unittest2 as unittest
except ImportError:
    import unittest


xpaths = { 'usernameTxtBox' : "//input[@id='inputUsername']",
           'passwordTxtBox' : "//input[@id='md-input-3']",
          'submitButton' : "/html/body/app/main/login/div/div/form/div[3]/div[1]/button",
          'newUser' : "//*[@id='md-input-7']",
         'newUserName' : "//*[@id='md-input-13']",
         'newUserPass' : "//*[@id='md-input-17']",
        'newUserPassConf' : "//*[@id='md-input-19']"
        }

class Freenasui(unittest.TestCase):
  @classmethod
  def setUpClass(inst):
    #create a new Firefox session
    caps = webdriver.DesiredCapabilities().FIREFOX
    caps["marionette"] = False
    inst.driver = webdriver.Firefox(capabilities=caps)
    inst.driver.implicitly_wait(30)
    inst.driver.maximize_window()
    inst.driver.get(baseurl())


  #Tests in numerals in order to sequence the tests
  #Test enter username,password,login and check successfully login
  def test_1_login(self):
    #enter username in the username textbox
    #self.driver.find_element_by_xpath(xpaths['usernameTxtBox']).send_keys("root")
    #enter password in the password textbox
    self.driver.find_element_by_xpath(xpaths['passwordTxtBox']).send_keys(password())
    #click
    #click
    self.driver.find_element_by_xpath("/html/body/app-root/app-auth-layout/app-signin/div/div/md-card/md-card-content/form/button").click()
    #check if the dashboard opens
    self.assertTrue(self.is_element_present(By.XPATH,"/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/app-breadcrumb/div"),"Unsuccessful Login")

  #Test navigation Account>Users>Hover>New User and enter username,fullname,password,confirmation and wait till user is  visibile in the list
  def test_2_create_newuser(self):
    #Click  Account menu 
    a = self.driver.find_element_by_xpath("//*[@id='scroll-area']/navigation/md-nav-list/div[2]/md-list-item/div/a")
    a.click()
    #allowing the button to load
    time.sleep(1)
    #Click User submenu
    self.driver.find_element_by_xpath("//*[@id='scroll-area']/navigation/md-nav-list/div[2]/md-list-item/div/md-nav-list/md-list-item[1]/div/a").click()
    #scroll down to find hover tab
    self.driver.find_element_by_tag_name('html').send_keys(Keys.END)
    time.sleep(2)
    #Perform hover to show menu
    hover_element = self.driver.find_element_by_xpath("/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/div/app-user-list/entity-table/div/app-entity-table-add-actions/div/smd-fab-speed-dial/div/smd-fab-trigger/button")
    hover = ActionChains(self.driver).move_to_element(hover_element)
    hover.perform()
    time.sleep(1)
    #Click create new user option
    self.driver.find_element_by_xpath("/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/div/app-user-list/entity-table/div/app-entity-table-add-actions/div/smd-fab-speed-dial/div/smd-fab-actions").click()
    #Enter New Username
    self.driver.find_element_by_xpath(xpaths['newUser']).send_keys(newusername())
    #Enter User Full name
    self.driver.find_element_by_xpath(xpaths['newUserName']).send_keys(newuserfname())
    #Enter Password
    self.driver.find_element_by_xpath(xpaths['newUserPass']).send_keys(newuserpassword())
    #Enter Password Conf
    self.driver.find_element_by_xpath(xpaths['newUserPassConf']).send_keys(newuserpassword())
    #Click on creat new User button
    self.driver.find_element_by_xpath("/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/div/app-user-form/entity-form/md-card/div/form/md-card-actions/button[1]").click()
    #check if the the user list is loaded after addding a new user
    self.assertTrue(self.is_element_present(By.XPATH, "/html/body/app-root/app-admin-layout/md-sidenav-container/div[6]/app-breadcrumb/div/ul/li[2]/a"), "User list not loaded")
    #wait to confirm new user in the list visually 
    time.sleep(15)


    # Next step-- To check if the new user is present in the list via automation


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
