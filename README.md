# Absolute coin (ABS) masternode wallet upgrade script

This script is used to upgrade a vps masternode wallet version of Absolute coin (ABS).

Use Putty to connect to your vps via ssh. Make sure you have at least Ubuntu Linux v18.04 installed.

You need to be root, so, if you use a different user to login to your vps then switch the current user to root and navigate to /root folder with this shell command:

	cd /root

Download the install script with this command:

	wget https://bit.ly/abs_mn_wallet_upgrade -O abs_wallet_upgrade.sh && chmod +x abs_wallet_upgrade.sh

Start the install script with the next command. 

	./abs_wallet_upgrade.sh

Make sure that the script run without errors!

Script will upgrade the wallet of running nodes, so no need to stop the daemons before running it. 
Hopefully it will detect your configuration and stop daemons, download new binaries, upgrade wallet binaries, update sentinel and restart the daemons... well... that's the plan...

Note: mannualy configured nodes with non default configurations and paths can't be upgraded with this script.

**Good luck!**

*If you run into problems ask for help in ABS discord support channel.*