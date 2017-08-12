
# to be executed on the raspi holding the FPGA

# download raspbian image and write it to the raspi boot media
# mount /boot of the raspi boot media and do
#touch ssh
#sudo aptitude update
#sudo aptitude install git

git clone git://git.drogon.net/wiringPi
cd wiringPi && ./build; cd ..

git clone https://github.com/cliffordwolf/icotools.git
cd icotools/icoprog && make install; cd ..

# one may want to configure teh device (turning on SPI, ...)
sudo raspi-config

# maybe you want to have g++ installed
#sudo aptitude install gpp

#sudo aptitude install python-dev
sudo aptitude install python-spidev


# to be executed locally
#ssh-keygen # verify ~/.ssh/id_rsa.pub not to exist other-
            # wise the existing keys might be overwritten
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@raspberypi

