Setup Selenium locally
===========

For Debian 8:
---

* Install nvm [node version manager](https://github.com/creationix/nvm):
```
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
```

* Install npm (node package manager) with nvm:
```
    nvm install node
```

* Install protractor (AngularJS's wrapper for selenium):
```
    npm install -g protractor
```

* Run webdriver update:
```
    webdriver-manager update
```

* Start webdriver:
```
    webdriver-manager start
```

Setup Selenium server
===========

For Debian 8 (TODO: some of the installs may not be needed, please prune):
---

* Download selenium server jar from http://docs.seleniumhq.org/download/
* Copy the jar file to the machine or VM that will act as the selenium server
* Install your webdrivers:
```
    # For Chromium:
    sudo apt-get install build-essential chromium default-jre default-jdk chromedriver
    ln -s /usr/lib/chromium/chromedriver /usr/bin/chromedriver
```

* Install Oracle's Java8 (may work with other versions, be my guest):
```
    sudo apt-get install software-properties-common
    sudo add-apt-repository "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main"
    sudo apt-get update && sudo apt-get install oracle-java8-installer oracle-java8-set-default
```

* Cross fingers and attempt running the selenium hub server with:
```
    java -jar selenium-server-standalone-<version>.jar -role hub
```

* Add a node (or four) to the selenium hub with:
```
    java -jar selenium-server-standalone-<version>.jar -role node  -hub http://localhost:4444/grid/register
```

* If everything is working, add the selenium hub command to /etc/rc.local and start-up some nodes in a screen session?


Running angular tests with protractor on the test executor
===========

* Install the node package manager (npm); find instructions for your OS - good luck.
* Install protractor globally with ```npm install -g protractor``` (may require root/sudo)
* Configure a running selenium server.


Helpful resources
===========

* [Selenium Wiki Documentation](https://github.com/SeleniumHQ/selenium/wiki)
* [Protractor for AngularJS](https://ramonvictor.github.io/protractor/slides/)
