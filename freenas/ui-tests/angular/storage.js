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
      var groups_el = $('.col-md-9 > ba-card:nth-child(1) > div:nth-child(1) > div:nth-child(2) > app-vdev:nth-child(1) > ba-card:nth-child(1) > div:nth-child(1) > div:nth-child(1) > div:nth-child(1)');
      browser.wait(protractor.ExpectedConditions.presenceOf(disk_el), 6000);
      browser.wait(protractor.ExpectedConditions.presenceOf(groups_el), 6000);

      expect(disk_el.getText()).toContain('ada1');

      // What should work for DND:
      //browser.actions().mouseDown(disk_el.getWebElement()).mouseMove(groups_el.getWebElement()).mouseUp().perform();
      //browser.actions().dragAndDrop(disk_el.getWebElement(), groups_el.getWebElement()).perform();

      // Hacks that should work and also do not:

      // Mimic moving the element via transition and absolute positioning, suggested by the dragula folks
      // https://github.com/bevacqua/dragula/issues/65
      //browser.executeScript(function() {
      //  var el = document.querySelector('app-disk:nth-child(1)');
      //  var target = document.querySelector('app-vdev > ba-card > div > div > div:nth-child(1)');
      //  var el_loc = el.getBoundingClientRect();
      //  var target_loc = target.getBoundingClientRect();
      //  el.style.transition = "all 0.3s ease-in-out";
      //  el.style.left = (el_loc.left - 40) + 'px';
      //  el.style.top = (el_loc.top - 40) + 'px';
      //  el.style.position = 'absolute';
      //  el.style.left = (target_loc.left - 90) + 'px';
      //  el.style.top = (target_loc.top - 190) + 'px';
      //  el.style.position = 'relative';
      //  el.style.top = 0;
      //  el.style.left = 0;
      //  target.append(el);
      //});

      // Use MouseEvents to mimic drag and drop
      //browser.executeScript(
      //  "let sel_mouse_evt = new MouseEvent('mousedown', { bubbles: true, cancelable: true });"
      //  + "let move_mouse_evt = new MouseEvent('mouseenter', { bubbles: true, cancelable: true });"
      //  + "let release_mouse_evt = new MouseEvent('mouseup', { bubbles: true, cancelable: true });"
      //  + "let dragfrom = document.querySelector('app-disk:nth-child(1)');"
      //  + "let dragto = document.querySelector('.col-md-9 > ba-card:nth-child(1) > div:nth-child(1) > div:nth-child(2) > app-vdev:nth-child(1) > ba-card:nth-child(1) > div:nth-child(1) > div:nth-child(1) > div:nth-child(1)');"
      //  + "dragfrom.setAttribute('draggable', true);"
      //  + "dragfrom.dispatchEvent(sel_mouse_evt);"
      //  + "dragto.dispatchEvent(move_mouse_evt);"
      //  + "dragfrom.dispatchEvent(release_mouse_evt);",
      //disk_el.getWebElement(), groups_el.getWebElement());

      // Use MouseEvents with positioning attributes
      //browser.executeScript(
      //  "function simulate(f,c,d,e){var b,a=null;for(b in eventMatchers)if(eventMatchers[b].test(c)){a=b;break}"
      //  + "if(!a)return!1;document.createEvent?(b=document.createEvent(a),a==\"HTMLEvents\"?b.initEvent(c,!0,!0):"
      //  + "b.initMouseEvent(c,!0,!0,document.defaultView,0,d,e,d,e,!1,!1,!1,!1,0,null),f.dispatchEvent(b)):"
      //  + "(a=document.createEventObject(),a.detail=0,a.screenX=d,a.screenY=e,a.clientX=d,a.clientY=e,a.ctrlKey="
      //  + "!1,a.altKey=!1,a.shiftKey=!1,a.metaKey=!1,a.button=1,f.fireEvent(\"on\"+c,a));return!0} var eventMatchers"
      //  + "={HTMLEvents:/^(?:load|unload|abort|error|select|change|submit|reset|focus|blur|resize|scroll)$/,"
      //  + "MouseEvents:/^(?:click|dblclick|mouse(?:down|up|over|move|out))$/}; "
      //  + "simulate(arguments[0],\"mousedown\",0,0); simulate(arguments[0],\"mousemove\",arguments[1],arguments[2]); "
      //  + "simulate(arguments[0],\"mouseup\",arguments[1],arguments[2]); ",
      //  disk_el.getWebElement(),
      //  xto,
      //  yto
      //);

      var create_btn = $('app-manager > div > div.row:nth-child(3) > div > button.btn-primary');
      expect(create_btn.getText()).toContain('Create');
      //create_btn.click();
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
