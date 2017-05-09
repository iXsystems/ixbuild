// System services: SMB, SSH, etc
// Requires: accounts, storage, shares
'use strict';

const accounts = require('./accounts.js');

var services = new Object();

// Service name: Order in which found in the services view
// Note: currently skipping some services due to first requiring configuration
services.service_idx = {
  'afp': 1,
  'smb': 2,
  'ftp': 5,
  'iscsi': 6,
  'lldp': 7,
  'nfs': 8,
  'rsync': 9,
  's3': 10,
  'snmp': 12,
  'ssh': 13,
  'tftp': 14,
  'webdav': 16
};

// Starts a service by the service name (services.service_idx)
services.start_service_by_name = function(servicename) {
  var idx = services.service_idx[servicename];

  describe(servicename + ' service', function() {
    it('should start', function() {
      browser.driver.getCurrentUrl().then(function(actualUrl) {
        if (actualUrl.indexOf('#/pages/services') == -1) {
          browser.get('#/pages/services');
        }
      });
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/services'), 6000);
      browser.wait(protractor.ExpectedConditions.presenceOf($('button.btn.btn-primary')), 30000);
      // protractor doesn't take into account the scrolling div.page-top element when scrolling
      // from the bottom of the view to focus on the first service element. This results on the
      // div.page-top element covering the top-most service's row, thus we scroll to the top of the
      // page when working with the top-most service element.
      if (idx == 1) browser.driver.executeScript('window.scrollTo(0, 0);');

      let btn = $('service:nth-child(' + idx + ') div.card-body > div.row > div:nth-child(3) > button');
      let status_el = $('service:nth-child(' + idx + ') div.card-body > div.row > div:nth-child(2) > span');
      btn.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          expect(status_el.getText()).toEqual('STOPPED');
          expect(btn.getText()).toEqual('Start');
          btn.click();
          browser.wait(protractor.ExpectedConditions.invisibilityOf($('service:nth-child(' + idx +') div.ng-busy')), 15000);
          expect(btn.getText()).toEqual('Stop');
          expect(status_el.getText()).toEqual('RUNNING');
        }
      });
    });
  });
  return true;
};

// Stops a service by the service name (services.service_idx)
services.stop_service_by_name = function(servicename) {
  var idx = services.service_idx[servicename];

  describe(servicename + ' service', function() {
    it('should stop', function() {
      browser.driver.getCurrentUrl().then(function(actualUrl) {
        if (actualUrl.indexOf('#/pages/services') == -1) {
          browser.get('#/pages/services');
        }
      });
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/services'), 6000);
      browser.wait(protractor.ExpectedConditions.presenceOf($('button.btn.btn-primary')), 30000); 
      // protractor doesn't take into account the scrolling div.page-top element when scrolling
      // from the bottom of the view to focus on the first service element. This results on the
      // div.page-top element covering the top-most service's row, thus we scroll to the top of the
      // page when working with the top-most service element.
      if (idx == 1) browser.driver.executeScript('window.scrollTo(0, 0);');

      let btn = $('service:nth-child(' + idx + ') div.card-body > div.row > div:nth-child(3) > button');
      let status_el = $('service:nth-child(' + idx + ') div.card-body > div.row > div:nth-child(2) > span');
      btn.isDisplayed().then(function(isVisable) {
        if (isVisable) {
          expect(status_el.getText()).toEqual('RUNNING');
          expect(btn.getText()).toEqual('Stop');
          btn.click();
          browser.wait(protractor.ExpectedConditions.invisibilityOf($('service:nth-child(' + idx +') div.ng-busy')), 15000);
          expect(btn.getText()).toEqual('Start');
          expect(status_el.getText()).toEqual('STOPPED');
        }
      });
    });
  });
  return true;
};

// Log in and then start all of the services
services.setUp = function() {
  accounts.login();
  for (var servicename in services.service_idx) {
    if (services.service_idx.hasOwnProperty(servicename)) {
      services.start_service_by_name(servicename);
    }
  }
};

// Stop all of the services and then log out
services.tearDown = function() {
  for (var servicename in services.service_idx) {
    if (services.service_idx.hasOwnProperty(servicename)) {
      services.stop_service_by_name(servicename);
    }
  }
  accounts.logout();
};

// Run all of the service tests
services.tests = function() {
  this.setUp();
  this.tearDown();
};

module.exports = services;
