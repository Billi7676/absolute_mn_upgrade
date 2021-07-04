#!/bin/bash

# set vars used by the script
declare -a abs_units
declare -a abs_confs

# wallet release to be upgraded to
wallet_ver="v0.14.0.1"
wallet_file="absolutecore-0.14.0-x86_64-linux-gnu.tar.gz"
wallet_url="https://github.com/absolute-community/absolute/releases/download/$wallet_ver"

# default wallet binaries path
wallet_path="/root/Absolute"
abs_chain_path="/root/.absolutecore"


function updateWallet
{
    echo "Download ABS daemon binaries"
    if [ ! -f "$wallet_file" ]; then
        echo "Downloading..."
        wget "$wallet_url/$wallet_file" -q && echo "...done!"
    else
        echo "File already downloaded!"
    fi

    wallet_dir_name=$(tar -tzf "$wallet_file" | head -1 | cut -f1 -d"/")

    if [ -z "$wallet_dir_name" ]; then
        echo "Failed - downloading ABS daemon binaries."
        exit 1
    fi

    echo "Extract ABS daemon binaries"
    if [ -d "$wallet_path" ]; then
        rm -r "$wallet_path"
    fi
	tar -zxvf "$wallet_file" && mv "$wallet_dir_name/bin" "$wallet_path"
    rm -r "$wallet_dir_name"
	if [ -f "/usr/local/bin/absolute-cli" ]; then
		rm /usr/local/bin/absolute-cli
	fi
	if [ -f "/usr/local/bin/absoluted" ]; then
		rm /usr/local/bin/absoluted
	fi
	ln -s "$wallet_path"/absolute-cli /usr/local/bin/absolute-cli
	ln -s "$wallet_path"/absoluted /usr/local/bin/absoluted
	rm "$wallet_file"
}


# entry point
clear
#cd /root

printf "\n===== ABS %s masternode vps update =====\n" $wallet_ver
printf "\n%s\n" "Installed OS: $(cut -d':' -f2 <<< "$(lsb_release -d)")"
printf "\n%s\n" "We are now in $(pwd) directory"

# get numbers of running daemons
abs_daemons=$(ps -ax | grep -v grep | grep "absoluted" -c)
if (( "$abs_daemons" == 0 )); then
    echo "Can't find any running daemons! Exiting..."
    exit 1
fi

# check if daemons are started with crontab or systemd unit
is_crontab=$(crontab -l | grep "absoluted" -c)
if (("$is_crontab" == 0)); then
    echo "No ABS daemons in crontab! Check for systemd units..."

    # get abs systemd unit(s)
    mapfile -t abs_units < <(systemctl status $(pidof absoluted) | grep CGroup | awk '{print $2}' | cut -f3 -d'/' | cut -f1 -d'.')
    if (("${#abs_units[@]}" == 0)); then
        echo "No systemd units found! Daemons started mannualy! Exiting..."
        exit 1
    fi

    # get abs conf(s)
    mapfile -t abs_confs < <(systemctl status $(pidof absoluted) | grep ExecStart | awk '{print $4}' | cut -f2 -d'=')

    # check if wallet path is on default location or try to find it
    if [ ! -d "$wallet_path" ]; then
        echo "Wallet path not on default location! Trying to find it..."
        wallet_path="/$(systemctl status ${abs_units[0]} | grep ExecStart | awk '{print $3}' | cut -f2-3 -d'/')"
        if (("$wallet_path" == "")); then
            echo "Could not find the wallet path! Exiting..."
            exit 1
        else
            echo "Found wallet path in $wallet_path"
        fi
    fi

    # stop daemons
    for abs_unit in "${abs_units[@]}"; do
        echo "Stopping ABS unit $abs_unit..."
        systemctl stop "$abs_unit"
        sleep 5
        echo "Done!"
    done

    # update wallet binaries
    echo "Update wallet binaries..."
    updateWallet
    sleep 5
    echo "Done!"

    # update sentinel in absolute confs
    for abs_conf in "${abs_confs[@]}"; do
        echo "Update sentinel for $abs_conf..."
        cd "$abs_conf/sentinel" && git pull
        sleep 5
        cd 
        echo "Done!"
    done

    # start daemons
    for abs_unit in "${abs_units[@]}"; do
        echo "Starting ABS unit $abs_unit..."
        systemctl start "$abs_unit"
        sleep 5
        echo "Done!"
    done

    echo "Upgrade done..."
    exit 0

else
    # check if wallet path is on default location 
    if [ ! -d "$wallet_path" ]; then
        echo "This is a mannualy configured node with no default wallet path!"
        echo "Automatic upgrade is not possible! Exiting..."
        exit 1
    fi

    # get absconf(s) from crontab
    mapfile -t abs_confs < <(crontab -l | grep "absoluted" | grep -oE '[^-]+' | grep "datadir" | cut -f2 -d'=')

    if (("$abs_daemons" == 1 && "${#abs_confs[@]}" == 0)); then
        # assume there is only one daemon started without datadir argument in crontab

        # stop the daemon
        echo "Stopping ABS daemon..."
        "$wallet_path"/absolute-cli stop
        sleep 5
        echo "Done!"

        # update wallet binaries
        echo "Update wallet binaries..."
        updateWallet
        sleep 5
        echo "Done!"

        # update sentinel in absolute confs
        cd "$abs_chain_path"/sentinel && git pull
        sleep 5
        echo "Done!"
        cd

        # start the daemon
        echo "Starting ABS daemon..."
        "$wallet_path"/absoluted -daemon
        sleep 5
        echo "Done!"

    else
        # assume more than one daemon started with crontab... absconfs must be at least as many as running daemons

        # stop the daemons
        for abs_conf in "${abs_confs[@]}"; do
            echo "Stopping ABS daemon for ${abs_conf// }..."
            "$wallet_path"/absolute-cli -datadir="${abs_conf// }" stop
            sleep 5
            echo "Done!"
        done

        # update wallet binaries
        echo "Update wallet binaries..."
        updateWallet
        sleep 5
        echo "Done!"

        # update sentinel in absolute confs
        for abs_conf in "${abs_confs[@]}"; do
            echo "Update sentinel for ${abs_conf// }..."
            cd "${abs_conf// }"/sentinel && git pull
            sleep 5
            cd 
            echo "Done!"
        done

        # start the daemons
        for abs_conf in "${abs_confs[@]}"; do
            echo "Starting ABS daemon for ${abs_conf// }..."
            "$wallet_path"/absoluted -datadir="${abs_conf// }" -daemon
            sleep 5
            echo "Done!"
        done
    fi
fi

echo "Upgrade done..."

