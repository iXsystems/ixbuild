describe('angularjs login', function() {
  it('should authenticate default user', function() {
    // http://stackoverflow.com/questions/36201691/protractor-angular-2-failed-unknown-error-angular-is-not-defined
    browser.ignoreSynchronization = true;
    browser.get('#/pages/dashboard');
    expect(browser.getCurrentUrl()).toContain('#/login');

    element(by.id('inputUsername')).sendKeys('root')
    element(by.id('inputPassword3')).sendKeys('testing')

    element(by.css('[type="submit"]')).click();

    expect(browser.getCurrentUrl()).toContain('#/pages/dashboard');
    browser.ignoreSynchronization = false;
  });
});
