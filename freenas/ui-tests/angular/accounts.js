// System accounts: users and groups

// http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
browser.ignoreSynchronization = true;

var accounts = new Object();

accounts.user_list = function() {
  return new Array(
    {
      'username': 'root',
      'password': 'testing'
    }
  );
};

// our default user will be the `root` account
accounts.default_user = function() {
  return this.user_list[0];
};

accounts.login = function(user) {

  // using our default `root` account unless otherwise passed as an arg
  var _user = typeof user Object ? user : this.default_user();

  describe('logging in as our root account ', function() {
    it('should authenticate the user and re-direct to the dashboard', function() {
      var username = element(by.id('inputUsername'));
      var password = element(by.id('inputPassword3'));

      username.clear();
      username.sendKeys(_user.username);

      password.clear();
      password.sendKeys(_user.password);

      element(by.css('[type="submit"]')).click();

      expect(browser.getCurrentUrl()).toContain('#/pages/dashboard');
    });
  });

  return true;
};

accounts.logout = function() {
  describe('logging out', function() {
    it('should re-direct to the login page with empty username/password input fields', function() {
      browser.get('#/pages/dashboard');

      element(by.id('user-profile-dd')).click();
      element(by.css('.signout')).click();

      expect(browser.getCurrentUrl()).toContain('#/login');
      expect(element(by.id('inputUsername')).getAttribute('value')).toEqual("");
    });
  });

  return true;
};


accounts.setUp = function() {
  accounts.login();
};

accounts.tearDown = function() {
  accounts.logout();
};

account.tests = function() {
  var self = this;

  expect(self.login()).toEqual(true);
  expect(self.logout()).toEqual(true);

  return true;
};

// restore previous value
browser.ignoreSynchronization = false;
