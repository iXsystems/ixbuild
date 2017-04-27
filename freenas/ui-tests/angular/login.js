describe('angularjs login', function() {
  it('should authenticate default user', function() {
    browser.get('#/login');

    element(by.model('username')).sendKeys('root')
    element(by.model('password')).sendKeys('testing')

    element(by.css('[type="submit"]')).click();

    expect(browser.getCurrentUrl()).toContain('#/pages/dashboard');
  });
});
