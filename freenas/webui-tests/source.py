# Author: Rishabh Chauhan
# License: BSD
# Location for tests of FreeNAS new GUI

def baseurl():
  return "http://10.250.1.133/ui"

def username():
  return "root"

def password():
  return "abcd1234"

def newusername():
  return "userNAS"

def newuserfname():
  return "user NAS"

def newuserpassword():
  return "abcd1234"




#method to test if an element is present-not used in the current script
def is_element_present_source(self, how, what):
  """
  Helper method to confirm the presence of an element on page
  :params how: By locator type
  :params what: locator value
  """
  try: self.driver.find_element(by=how, value=what)
  except NoSuchElementException: return False
  return True

