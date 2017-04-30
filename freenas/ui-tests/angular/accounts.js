// System accounts: users and groups
'use strict';

var accounts = new Object();

accounts.user_list = new Array(
  {
    'username': 'root',
    'password': 'testing'
  }
);

// our default user will be the `root` account
accounts.default_user = function() {
  var self = this;
  return self.user_list[0];
};

accounts.login = function() {
  var _user = accounts.default_user();

  describe('logging in as our root account ', function() {
    it('should authenticate the user and re-direct to the dashboard', function() {
      // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
      browser.ignoreSynchronization = true;
      browser.get('#/login');

      var username = $('#inputUsername');
      var password = $('#inputPassword3');

      username.isPresent();
      password.isPresent();

      username.clear();
      username.sendKeys(_user['username']);

      password.clear();
      password.sendKeys(_user['password']);

      element(by.css('[type="submit"]')).click();

      browser.wait(function() {
        return browser.driver.getCurrentUrl().then(function(actualUrl) {
          return actualUrl.indexOf('#/pages/dashboard') >= 0;
        });
      }, 3000);

      expect(browser.driver.getCurrentUrl()).toContain('#/pages/dashboard');

      // restore previous value
      browser.ignoreSynchronization = false;
    });
  });

  return true;
};

accounts.logout = function() {
  describe('logging out', function() {
    it('should re-direct to the login page with empty username/password input fields', function() {
      // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
      browser.ignoreSynchronization = true;
      browser.get('#/pages/dashboard');

      var profile_menu = $('#user-profile-dd');
      profile_menu.isPresent();
      profile_menu.click();

      var signout_link = $('.signout');
      signout_link.isPresent();
      signout_link.click();

      //element(by.id('user-profile-dd')).click();
      //element(by.css('.signout')).click();

      expect(browser.driver.getCurrentUrl()).toContain('#/login');

      var username = $('#inputUsername');

      expect(username.isPresent()).toBe(true);
      expect(browser.driver.getCurrentUrl()).toContain('#/login');
      //expect(element(by.id('inputUsername')).getAttribute('value')).toEqual("");

      // restore previous value
      browser.ignoreSynchronization = false;
    });
  });

  return true;
};

accounts.test_invalid_login = function() {
  describe('before logging in', function() {
    it('an invalid login attempt should be rejected', function() {
      // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
      browser.ignoreSynchronization = true;
      browser.get('#/login');

      var username = $('#inputUsername');
      var password = $('#inputPassword3');

      username.isPresent();
      password.isPresent();

      username.clear();
      username.sendKeys('invalidlogin');
      password.clear();
      password.sendKeys('invalidpassword');

      $('[type="submit"]').click();

      var error_msg = $$('div.form-group').first();
      expect(error_msg.getText()).toEqual('Username or password invalid!');
    });
  });
};

accounts.setUp = function() {
  accounts.test_invalid_login();
  accounts.login();
};

accounts.tearDown = function() {
  accounts.logout();
};

accounts.tests = function() {
  var self = this;

  self.setUp();
  self.tearDown();

  return true;
};

accounts.tests();
