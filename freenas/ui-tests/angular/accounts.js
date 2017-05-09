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
  var _user = this.default_user();

  describe('logging in as our root account ', function() {
    it('should authenticate the user and re-direct to the dashboard', function() {
      browser.get('#/login');
      browser.wait(protractor.ExpectedConditions.urlContains('#/login'), 6000);
      browser.wait(protractor.ExpectedConditions.presenceOf($('#inputUsername')), 6000);

      var username = $('#inputUsername');
      username.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          username.clear();
          username.sendKeys(_user['username']);
        }
      });
      var password = $('#inputPassword3');
      password.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          password.clear();
          password.sendKeys(_user['password']);
        }
      });

      $('[type="submit"]').click();

      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/dashboard'), 6000);
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/dashboard');
    });
  });

  return true;
};

accounts.logout = function() {
  describe('logging out', function() {
    it('should re-direct to the login page with empty username/password input fields', function() {
      browser.get('#/pages/dashboard');
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/dashboard'), 6000);

      var profile_menu = $('#user-profile-dd');
      profile_menu.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          profile_menu.click();
        }
      });

      var signout_link = $('.signout');
      signout_link.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          signout_link.click();
        }
      });

      browser.wait(protractor.ExpectedConditions.urlContains('#/login'), 6000);
      expect(browser.driver.getCurrentUrl()).toContain('#/login');
      var username = $('#inputUsername');
      expect(username.isPresent()).toBe(true);
    });
  });

  return true;
};

accounts.test_invalid_login = function() {
  describe('before logging in', function() {
    it('an invalid login attempt should be rejected', function() {
      browser.get('#/login');

      var username = $('#inputUsername');
      browser.wait(protractor.ExpectedConditions.presenceOf(username), 5000);

      username.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          username.clear();
          username.sendKeys('invalidlogin');
        }
      });

      var password = $('#inputPassword3');
      password.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          password.clear();
          password.sendKeys('invalidpassword');
        }
      });

      $('[type="submit"]').click();

      var error_msg = $$('div.form-group').first();
      expect(error_msg.getText()).toEqual('Username or password invalid!');
    });
  });
};

accounts.test_add_user = function() {

  var user_data = {
    username: 'new_test_user',
    full_name: 'New TestUser',
    home: '/nonexistent',
    password: 'testing'
  };

  describe('adding a new user', function() {
    it('should be able to navigate to the add users view from user listing', function() {
      browser.get('#/pages/users');
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/users'), 6000);
      browser.wait(protractor.ExpectedConditions.invisibilityOf($('.ng-busy-default-wrapper')), 5000);

      let add_btn = $('button.btn.btn-primary.btn-add');
      add_btn.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          expect(add_btn.isPresent()).toBe(true);
          add_btn.click();
        }
      });

      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/users/add'), 6000);
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users/add');
    });
    it('should allow a valid new user to be added', function() {
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users/add');

      let username = $('#bsdusr_username');
      username.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          username.clear();
          username.sendKeys(user_data['username']);
        }
      });

      let fullname = $('#bsdusr_full_name');
      fullname.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          fullname.clear();
          fullname.sendKeys(user_data['full_name']);
        }
      });

      let home_dir = $('#bsdusr_home');
      home_dir.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          home_dir.clear();
          home_dir.sendKeys(user_data['home']);
        }
      });

      let password = $('#bsdusr_password');
      password.isDisplayed().then(function(isVisable) {
          if (isVisable) {
            password.clear();
            password.sendKeys(user_data['password']);
          }
      });

      let creategroup_chkbox = $('#bsdusr_creategroup');
      creategroup_chkbox.isDisplayed().then(function() {
        // TODO - check if the default changed to checked?
        creategroup_chkbox.click();
      });

      let add_btn = $$('button.btn.btn-primary').first();
      expect(add_btn.getText()).toEqual('Add');
      add_btn.click();
    });
    it('should list the newly created user in the users list', function() {
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/users'), 6000);
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users');

      // Make sure the user list has finished loading
      browser.wait(protractor.ExpectedConditions.presenceOf($('app-entity-list-actions')), 6000);

      $$('table > tbody > tr').each(function(row, idx) {
        // Find the row where the username column contains our new user
        row.$('td:nth-child(1)').getText().then(function(username) {
          if (username == user_data['username']) {
            expect(row.$('td:nth-child(1)').getText()).toEqual(user_data['username']);
            expect(row.$('td:nth-child(4)').getText()).toEqual(user_data['home']);
            expect(row.$('td:nth-child(6)').getText()).toEqual('false');
            row.$$('app-entity-list-actions > span > button').each(function(btn, btn_idx) {
              btn.getText().then(function(btn_text) {
                if (btn_text == 'Delete') {
                  btn.click();
                }
              });
            });
          }
        });
      });
    });
  });
}

accounts.setUp = function() {
  accounts.login();
};

accounts.tearDown = function() {
  accounts.logout();
};

accounts.tests = function() {
  var self = this;

  accounts.test_invalid_login();
  self.setUp();
  //accounts.test_add_user();
  self.tearDown();

  return true;
};

module.exports = accounts;
