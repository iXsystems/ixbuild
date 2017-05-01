Running AngularJS UI tests
===========

### Locally ###

* [Setup Selenium locally](#setup-selenium-locally)


And run:

```
./runtests.sh
```

### Jenkins ###

* [Setup Selenium server](#setup-selenium-server)
* [Setup test executor](#setup-test-executor)


Setup Selenium locally
===========

### Debian 8 ###

Install nvm [node version manager](https://github.com/creationix/nvm):

```
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
```

Install npm (node package manager) with nvm:

```
    nvm install node
```

Install protractor (AngularJS's wrapper for selenium):

```
    npm install -g protractor
```

Run webdriver update:

```
    webdriver-manager update
```

Start webdriver:

```
    webdriver-manager start
```

* Copy ./config.prod to ./config.local, updating the $SELENIUMSERVER to localhost
* Run the ui-tests with ./runtests.sh


Setup Selenium server
===========

### Debian 8 ###

Download selenium server jar from http://docs.seleniumhq.org/download

Copy the jar file to the machine or VM that will act as the selenium server

Install chromium webdriver

```
    sudo apt-get install build-essential chromium default-jre default-jdk chromedriver
    ln -s /usr/lib/chromium/chromedriver /usr/bin/chromedriver
```

Install Oracle's Java8

```
    sudo apt-get install software-properties-common
    sudo add-apt-repository "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main"
    sudo apt-get update && sudo apt-get install oracle-java8-installer oracle-java8-set-default
```

Run the selenium hub server

```
    java -jar selenium-server-standalone-<version>.jar -role hub
```

Add node(s) to the selenium hub

```
    java -jar selenium-server-standalone-<version>.jar -role node  -hub http://localhost:4444/grid/register
```

### Setup test executor ###

Install nvm [node version manager](https://github.com/creationix/nvm):

```
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
```

Install npm (node package manager) with nvm:

```
    nvm install node
```

Install protractor (AngularJS's wrapper for selenium):

```
    npm install -g protractor
```

* Copy ./config.prod to ./config.local, updating the $SELENIUMSERVER setting
* Run the ui-tests locally with ./runtests.sh


Resources
=========

* [Selenium Wiki Documentation](https://github.com/SeleniumHQ/selenium/wiki)
* [Protractor for AngularJS](https://ramonvictor.github.io/protractor/slides/)
