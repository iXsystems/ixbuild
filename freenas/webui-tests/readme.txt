#Important Readme(under construction)

#Installations
cd ~/
sudo apt-get install python-pip
sudo pip install --upgrade pip
sudo pip install selenium
sudo apt-get install python-pytest
sudo apt-get install git


#Geckodriver 
wget https://github.com/mozilla/geckodriver/releases/download/v0.11.1/geckodriver-v0.11.1-linux64.tar.gz
git clone https://github.com/rishabh27892/webui-test-files/
cd webui-test-files/
tar -xvzf geckodriver-v0.11.1-linux64.tar.gz
rm geckodriver-v0.11.1-linux64.tar.gz
chmod +x geckodriver
sudo cp geckodriver /usr/local/bin/

#Download ixbuild repo
git clone https://github.com/ixsystems/ixbuild/
cd ixbuild/freenas/webui-tests/

#Tests…….


#Generate XML result:
py.test --junitxml results.xml login.py
pytest format(-junitxml) <nameofresultfile> <testfile>


