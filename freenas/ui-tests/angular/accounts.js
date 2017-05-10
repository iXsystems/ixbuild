// System accounts: users and groups
'use strict';

const EC = protractor.ExpectedConditions;

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
      browser.wait(EC.urlContains('#/login'), 6000);
      browser.wait(EC.presenceOf($('#inputUsername')), 6000);

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

      browser.wait(EC.urlContains('#/pages/dashboard'), 6000);
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/dashboard');
    });
  });

  return true;
};

accounts.logout = function() {
  describe('logging out', function() {
    it('should re-direct to the login page with empty username/password input fields', function() {
      browser.get('#/pages/dashboard');
      browser.wait(EC.urlContains('#/pages/dashboard'), 6000);

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

      browser.wait(EC.urlContains('#/login'), 6000);
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
      expect(browser.driver.getCurrentUrl()).toContain('#/login');

      var username = $('#inputUsername');
      browser.wait(EC.presenceOf(username), 5000);

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

  describe('managing users', function() {
    it('should allow listing the users with navigation to creating new users', function() {
      browser.get('#/pages/users');
      browser.wait(EC.urlContains('#/pages/users'), 6000);
      browser.wait(EC.invisibilityOf($('.ng-busy-default-wrapper')), 5000);

      let add_btn = $('button.btn.btn-primary.btn-add');
      add_btn.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          expect(add_btn.isPresent()).toBe(true);
          add_btn.click();
        }
      });

      browser.wait(EC.urlContains('#/pages/users/add'), 6000);
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

      browser.wait(EC.urlContains('#/pages/users'), 15000);
    });
    it('should list the newly created user in the users list', function() {
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users');

      // Make sure the user list has finished loading
      browser.wait(EC.presenceOf($('app-entity-list-actions')), 15000);

      var row = $$('table > tbody > tr').filter(function(elem) {
        return elem.$('td:nth-child(1)').getText().then(function(username) {
          return username === user_data['username'];
        });
      }).first();
      expect(row.$('td:nth-child(1)').getText()).toEqual(user_data['username']);
      expect(row.$('td:nth-child(4)').getText()).toEqual(user_data['home']);
      expect(row.$('td:nth-child(6)').getText()).toEqual('false');
    });
    it('should allow the user to be deleted from the user list', function() {
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users');
      var row = $$('table > tbody > tr').filter(function(elem) {
        return elem.$('td:nth-child(1)').getText().then(function(username) {
          return username === user_data['username'];
        });
      }).first();
      var del_btn = row.$$('app-entity-list-actions > span > button').filter(function(elem) {
        return elem.getText().then(function(btn_txt) {
          return btn_txt === 'Delete';
        });
      });

      expect(del_btn.getText()).toContain('Delete');
      del_btn.click();

      browser.wait(EC.urlContains('#/pages/users/delete/'), 15000);
    });
    it('should allow deletion of newly created user', function() {
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users/delete/');

      var confirm_btn = $('button.btn-danger');
      browser.wait(EC.presenceOf(confirm_btn), 15000);

      expect(confirm_btn.getText()).toEqual('Yes');
      confirm_btn.click();

      browser.wait(EC.urlContains('#/pages/users'), 15000);
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users');
    });
    it('should no longer list deleted user in the user list', function() {
      browser.driver.getCurrentUrl().then(function(actualUrl) {
        if (actualUrl.indexOf('#/pages/users') < 0) {
          browser.get('#/pages/users');
        }
      });
      expect(browser.driver.getCurrentUrl()).toContain('#/pages/users');
      var row = $$('table > tbody > tr').filter(function(elem) {
        return elem.$('td:nth-child(1)').getText().then(function(username) {
          return username === user_data['username'];
        });
      }).first();
      expect(row.isPresent()).toBeFalsy();
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
  accounts.test_add_user();
  self.tearDown();

  return true;
};

module.exports = accounts;
