// System storage: volumes, snapshots
'use strict';

const accounts = require('./accounts.js');

var storage = new Object();

storage.volumes = new Object();

storage.volumes.create = function() {
  var self = this;
  describe('storage volume', function() {
    it('should be added', function() {
      browser.get('#/pages/storage/volumes/manager');
      browser.wait(protractor.ExpectedConditions.urlContains('#/pages/storage/volumes/manager'));

      var vol_name_el = $('input.form-control');
      vol_name_el.sendKeys('testvol');

      var disk_el = $('app-disk:nth-child(1)')
      var groups_el = $('app-vdev > ba-card > div > div > div:nth-child(1)')
      browser.wait(protractor.ExpectedConditions.presenceOf(disk_el), 6000);
      browser.wait(protractor.ExpectedConditions.presenceOf(groups_el), 6000);

      expect(disk_el.getText()).toContain('ada1');

      // https://github.com/bevacqua/dragula/issues/65
      browser.executeScript(function() {
        var el = document.querySelector('app-disk:nth-child(1)');
        var target = document.querySelector('app-vdev > ba-card > div > div > div:nth-child(1)');
        var el_loc = el.getBoundingClientRect();
        var target_loc = target.getBoundingClientRect();
        el.style.transition = "all 0.3s ease-in-out";
        el.style.left = (el_loc.left - 40) + 'px';
        el.style.top = (el_loc.top - 40) + 'px';
        el.style.position = 'absolute';
        el.style.left = (target_loc.left - 90) + 'px';
        el.style.top = (target_loc.top - 190) + 'px';
        el.style.position = 'relative';
        el.style.top = 0;
        el.style.left = 0;
        target.append(el);
      });

      //browser.actions().mouseDown(disk_el.getWebElement()).mouseMove(groups_el.getWebElement()).mouseUp().perform();
      //browser.actions().dragAndDrop(disk_el.getWebElement(), groups_el.getWebElement()).perform();

      //$('app-manager > div > div.row:nth-child(3) > div > button.btn-primary').click();
      //browser.pause();
    });
    //it('should populate the storage list with the new volume', function() {
    //  
    //});
  });

  return true;
};

storage.snapshots = new Object();

storage.tests = function() {
  var self = this;

  accounts.login();
  self.volumes.create();

  return true;
};

module.exports = storage;
