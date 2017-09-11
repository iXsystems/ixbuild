#Important Readme(under construction)

#Installations
sudo apt-get install python-pip
pip install --upgrade pip
pip install selenium
sudo apt install python-pytest

#Geckodriver 
wget https://github.com/mozilla/geckodriver/releases/download/v0.11.1/geckodriver-v0.11.1-linux64.tar.gz
tar -xvzf geckodriver-v0.11.1-linux64.tar.gz
rm geckodriver-v0.11.1-linux64.tar.gz
chmod +x geckodriver
sudo cp geckodriver /usr/local/bin/

#Git
sudo apt-get install git
git clone https://github.com/ixsystems/ixbuild/
cd ixbuild/freenas/webui-tests/

#Tests…….


#Generate XML result:
py.test --junitxml results.xml login.py
pytest format(-junitxml) <nameofresultfile> <testfile>


