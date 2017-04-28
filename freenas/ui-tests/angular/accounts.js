accounts = new Object();

accounts.user_list = [
  {
    'username': 'root',
    'password': 'testing'
  }
];

accounts.default_user = function(){
  return this.user_list[0];
};

accounts.login = function(){

  var user = this.default_user();

  describe('angularjs login', function() {
    it('should authenticate default user', function() {
      // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
      browser.ignoreSynchronization = true;
      browser.get('#/pages/dashboard');
      expect(browser.getCurrentUrl()).toContain('#/login');

      element(by.id('inputUsername')).sendKeys(user.username)
      element(by.id('inputPassword3')).sendKeys(user.password)

      element(by.css('[type="submit"]')).click();

      expect(browser.getCurrentUrl()).toContain('#/pages/dashboard');
      browser.ignoreSynchronization = false;
    });
  });
};

accounts.logout = function(){
  describe('angularjs logout', function() {
    it('should sign out the default user', function() {
      // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
      browser.ignoreSynchronization = true;

      // verify we are logged in, thus redirected to the dashboard from /login
      browser.get('#/login');
      expect(browser.getCurrentUrl()).toContain('#/pages/dashboard');

      // logout
      browser.get('#/pages/dashboard');
      element(by.css('[type="submit"]')).click();
      expect(browser.getCurrentUrl()).toContain('#/login');

      // ensure we can no longer access the dashboard
      browser.get('#/pages/dashboard')
      expect(browser.getCurrentUrl()).toContain('#/login');

      browser.ignoreSynchronization = false;
    });
  });
};


accounts.setUp = function(){
  accounts.login();
};

accounts.tearDown = function(){
  accounts.logout();
};

// Group tests

// User and Group with filesystem tests
//  -- Dataset
//  -- LDAP
//  -- Shares
