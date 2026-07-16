#!/bin/sh

# Define variables
SESSIONID=$(curl -s -X POST "http://localhost/web/session" | grep -o -E "<e2sessionid>(.*)</e2sessionid>" | sed "s|.*<e2sessionid>\(.*\)</e2sessionid>.*|\1|")
LANGUAGE=$(grep 'config.osd.language' /etc/enigma2/settings | cut -d'=' -f2)
oscheck=$(grep 'VERSION=' /etc/os-release | cut -d '"' -f2)
archeck=$(grep 'Architecture "' /etc/apt/apt.conf | cut -d '"' -f2)
apturl="http://download.blue-panel.com/gemini4/"
device_name="unknown"
filter_file="/etc/enigma2/AddonFilterlist_Nobody.json"
feed_file="/etc/apt/sources.list.d/gp4gz-$archeck.list"

# Function to install required tools
function install_tools() {
    # Install wget if not already installed
    if ! dpkg -s wget >/dev/null 2>&1; then
        echo -e "\e[34mInstalling wget...\e[0m"
        apt install -y wget
    else
        echo -e "\e[34mwget is already installed.\e[0m"
    fi

    # Install curl if not already installed
    if ! dpkg -s curl >/dev/null 2>&1; then
        echo -e "\e[34mInstalling curl...\e[0m"
        cd /tmp || exit
        if [ "$archeck" = "arm64" ]; then
            wget -O curl.deb "https://www.dreamboxupdate.com/opendreambox/2.6/unstable/r1/dreamtwo/deb/aarch64/curl_7.53.1-r0.4_arm64.deb"
        elif [ "$archeck" = "armhf" ]; then
            wget -O curl.deb "https://www.dreamboxupdate.com/opendreambox/2.5/unstable/r0/dm920/deb/cortexa15hf-neon-vfpv4/curl_7.47.1-r0.4_armhf.deb"
        elif [ "$archeck" = "mipsel" ]; then
            wget -O curl.deb "https://www.dreamboxupdate.com/opendreambox/2.2/unstable/r1/dm520/deb/mips32el/curl_7.32.0-r0.5_mipsel.deb"
        else
            echo -e "\e[31mUnsupported architecture\e[0m"
            exit 1
        fi

        dpkg -i curl.deb >/dev/null 2>&1
        rm -f curl.deb
    else
        echo -e "\e[34mcurl is already installed.\e[0m"
    fi
}

# Function to install dependencies
function install_dependencies() {
    # Install apt-transport-https if not already installed
    if ! dpkg -s apt-transport-https >/dev/null 2>&1; then
        echo -e "\e[34mInstalling apt-transport-https...\e[0m"
        cd /tmp || exit
        if [ "$archeck" = "arm64" ]; then
            wget -O apt-transport-https.deb "https://www.dreamboxupdate.com/opendreambox/2.6/unstable/r1/dreamtwo/deb/aarch64/apt-transport-https_1.2.12-r0.6_arm64.deb"
            wget -O libcurl4.deb "https://www.dreamboxupdate.com/opendreambox/2.6/unstable/r1/dreamtwo/deb/aarch64/libcurl4_7.53.1-r0.4_arm64.deb"
        elif [ "$archeck" = "armhf" ]; then
            wget -O apt-transport-https.deb "https://www.dreamboxupdate.com/opendreambox/2.5/unstable/r0/dm920/deb/cortexa15hf-neon-vfpv4/apt-transport-https_1.0.10.1-r0.4_armhf.deb"
            wget -O libcurl4.deb "https://www.dreamboxupdate.com/opendreambox/2.5/unstable/r0/dm920/deb/cortexa15hf-neon-vfpv4/libcurl4_7.47.1-r0.4_armhf.deb"
        elif [ "$archeck" = "mipsel" ]; then
            wget -O apt-transport-https.deb "https://www.dreamboxupdate.com/opendreambox/2.2/unstable/r1/dm520/deb/mips32el/apt-transport-https_1.0.9-r0.5_mipsel.deb"
            wget -O libcurl4.deb "https://www.dreamboxupdate.com/opendreambox/2.2/unstable/r1/dm520/deb/mips32el/libcurl4_7.32.0-r0.5_mipsel.deb"
        else
            echo -e "\e[31mUnsupported architecture\e[0m"
            exit 1
        fi

        dpkg -i apt-transport-https.deb libcurl4.deb >/dev/null 2>&1
        rm -f apt-transport-https.deb libcurl4.deb
    else
        echo -e "\e[34mapt-transport-https is already installed.\e[0m"
    fi
}

# Function to install packagegroup-gemini-best and dreamarabia-addons-feed
function install_packagegroup_gemini_best() {
    # Install packagegroup-gemini-best if not already installed
    if ! dpkg -s packagegroup-gemini-best >/dev/null 2>&1; then
        echo -e "\e[34mInstalling packagegroup-gemini-best...\e[0m"
        apt install -y packagegroup-gemini-best
        sleep 2
        install_tools
        sleep 2
    else
        echo -e "\e[34mpackagegroup-gemini-best is already installed.\e[0m"
    fi

    # Install dreamarabia-addons-feed if not already installed
    if ! dpkg -s dreamarabia-addons-feed >/dev/null 2>&1; then
        echo -e "\e[34mInstalling dreamarabia-addons-feed...\e[0m"
        apt install -y dreamarabia-addons-feed
        sleep 2
        install_dependencies
    else
        echo -e "\e[34mdreamarabia-addons-feed is already installed.\e[0m"
    fi
}

# Function to check and add repository entries
function check_and_add_repositories() {
    if grep -q "feed.dreamboxtools.de" /etc/apt/sources.list; then
        echo -e "\e[34m#######################\n#     Adding GP4      #\n#######################\e[0m"
        # Replace old feed URL with the new one
        echo "Replacing old feed URL with the new one..."
        sed -i 's/feed\.dreamboxtools\.de/merlinfeed\.boxpirates\.to/g' /etc/apt/sources.list
        echo "New source list:"
        cat /etc/apt/sources.list
        sleep 2
        echo -e "\e[34m#######################\n#     Adding GP4      #\n#######################\e[0m"
        _createFeedConf
        added_filter
    elif grep -q "merlinfeed.boxpirates.to" /etc/apt/sources.list && ! grep -q "$apturl" /etc/apt/sources.list; then
        echo -e "\e[34m#######################\n#     Adding GP4      #\n#######################\e[0m"
        _createFeedConf
        added_filter
    elif grep -q "merlinfeed.boxpirates.to" /etc/apt/sources.list && grep -q "$apturl" /etc/apt/sources.list; then
        echo -e "\e[34mGP4 already installed.\e[0m"
        sleep 2
        sleep 2
        echo -e "\e[34mLet's try installing packages...\e[0m"
        sleep 2
        install_packagegroup_gemini_best
        sleep 2
        apt update
        sleep 2
        apt-get -y upgrade
        sleep 5
        install_dependencies
        sleep 2
        ostende
        remove_chunk
    else
        echo -e "\e[34mFeed URL not found in sources.list. Skipping...\e[0m"
    fi
}

# Function to create feed configuration
function _createFeedConf() {
    # Additional lines
    if [ "$archeck" = "arm64" ]; then
        oe="pyro"
        archeck="aarch64"
        apturl="http://download.blue-panel.com/gemini4/${oe}-gemini4-unstable/"
        extraPlugins="extraPluginsAarch64"
        extrAddons="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Addons/"
        extraCams="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Cams/"
        extraSetting="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Settings/"
        extraFeed="https://apt.fury.io/gp4gz-aarch64/"
        nobodycam="https://apt.fury.io/nobody/"
    elif [ "$archeck" = "armhf" ]; then
        oe="krogoth"
        apturl="http://download.blue-panel.com/gemini4/${oe}-gemini4-unstable/"
        extraPlugins="extraPluginsArmhf"
        extrAddons="http://dreambox4u.com/dreamarabia/2.5/DreamArabia-Addons/"
        extraCams="http://dreambox4u.com/dreamarabia/2.5/DreamArabia-Cams/"
        extraSetting="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Settings/"
        extraFeed=" https://apt.fury.io/gp4gz-armhf/"
        nobodycam="https://apt.fury.io/nobody-armhf/"
    elif [ "$archeck" = "mipsel" ]; then
        oe="krogoth"
        apturl="http://download.blue-panel.com/gemini4/${oe}-gemini4-unstable/"
        extraPlugins="extraPluginsMipsel"
        extrAddons="http://dreambox4u.com/dreamarabia/2.5/DreamArabia-Addons/"
        extraCams="http://dreambox4u.com/dreamarabia/2.5/DreamArabia-Cams/"
        extraSetting="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Settings/"
        extraFeed="https://apt.fury.io/gp4gz-mipsel/"
        nobodycam="https://apt.fury.io/nobody-mipsel/"
    else
        echo -e "\e[31mUnsupported architecture\e[0m"
        exit 1
    fi

    if [ "$apturl" ]; then
        if ! grep -q "${apturl}all " /etc/apt/sources.list; then
            echo "deb [trusted=yes] ${apturl}all ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "$apturl$archeck " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $apturl$archeck ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "${apturl}allcodes " /etc/apt/sources.list; then
            echo "deb [trusted=yes] ${apturl}allcodes ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $apturl$extraPlugins " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $apturl$extraPlugins ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $extrAddons " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $extrAddons ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $extraCams " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $extraCams ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $extraSetting " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $extraSetting ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $extraFeed " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $extraFeed ./" >> /etc/apt/sources.list
        fi
        if ! grep -q "deb [trusted=yes] $nobodycam " /etc/apt/sources.list; then
            echo "deb [trusted=yes] $nobodycam ./" >> /etc/apt/sources.list
        fi
    fi
}

# Function to remove chunk if Merlin image
function remove_chunk() {
    if grep -q "merlinfeed.boxpirates.to" /etc/apt/sources.list; then
        rm -f /etc/apt/sources.list.d/dreamarabia-addons.list
        rm -f /etc/apt/sources.list.d/nobody-$archeck.list
        rm -f /etc/apt/sources.list.d/gp4gz-$archeck.list
    else
        echo -e "\e[34mNot a Merlin image. Chunk removal skipped.\e[0m"
    fi
}

# Function to add filter
function added_filter() {
    if [ -f "$filter_file" ]; then
        echo -e "\e[34mAddonFilterlist_Nobody.json already exists.\e[0m"
    else
        echo -e "\e[34mDownloading AddonFilterlist_Nobody.json...\e[0m"
        wget -O "$filter_file" "http://dreambox4u.com/dreamarabia/scripts/AddonFilterlist_Nobody.json"
        wget -O "$feed_file" "http://dreambox4u.com/dreamarabia/scripts/gp4gz-$archeck.list"
    fi
}

function ostende() {
    if [ "$archeck" = "arm64" ]; then
        nobodycam="/etc/apt/sources.list.d/nobody-$archeck.list"
    elif [ "$archeck" = "armhf" ]; then
        nobodycam="/etc/apt/sources.list.d/nobody-$archeck.list"
    elif [ "$archeck" = "mipsel" ]; then
        nobodycam="/etc/apt/sources.list.d/nobody-$archeck.list"
    else
        echo -e "\e[31mUnsupported architecture\e[0m"
        exit 1
    fi

    if [ "$archeck" ]; then
        wget -O "$nobodycam" "http://dreambox4u.com/dreamarabia/scripts/nobody-$archeck.list"
        install_dreamarabia_feed
        added_filter
    fi
}

# Function to install DreamArabia feed
function install_dreamarabia_feed() {
    echo -e "\e[34mChecking if DreamArabia-feed is already installed...\e[0m"
    if dpkg -s dreamarabia-addons-feed >/dev/null 2>&1; then
        echo -e "\e[34mDreamArabia-feed is already installed.\e[0m"
    else
        echo -e "\e[34mDreamArabia-feed will be installed\e[0m"

        if [ "$archeck" = "arm64" ]; then
            feed_url="http://dreambox4u.com/dreamarabia/2.6/DreamArabia-Addons/dreamarabia-addons-feed.deb"
        elif [ "$archeck" = "armhf" ]; then
            feed_url="http://dreambox4u.com/dreamarabia/2.5/DreamArabia-Addons/dreamarabia-addons-feed.deb"
        else
            echo -e "\e[31mUnsupported architecture\e[0m"
            exit 1
        fi
        cd /tmp || exit
        wget -O dreamarabia-addons-feed.deb "$feed_url"
        dpkg -i dreamarabia-addons-feed.deb >/dev/null 2>&1
        rm -f dreamarabia-addons-feed.deb
    fi
}

# Main Execution Flow
if [ -f /etc/apt/sources.list ]; then
    # Check if feed.dreamboxtools.de exists in sources.list
    if grep -q "feed.dreamboxtools.de" /etc/apt/sources.list; then
        check_and_add_repositories
    # Check if merlinfeed.boxpirates.to exists in sources.list
    elif grep -q "merlinfeed.boxpirates.to" /etc/apt/sources.list; then
        echo -e "\e[34m#######################\n#######################\n#######################\n#    Wait Please  ...   #\n#  Creat feed config  #\n#######################\n#######################\n#######################\e[0m"
        check_and_add_repositories
        echo -e "\e[34mLet's try installing packages...\e[0m"
        sleep 2
        install_packagegroup_gemini_best
        sleep 2
        apt update
        sleep 2
        apt-get -y upgrade
        sleep 5
        install_dependencies
        sleep 2
        ostende
    else
        echo -e "\e[34m#######################\n#######################\n#######################\n#    Wait Please  ...   #\n#  Creat feed config  #\n#######################\n#######################\n#######################\e[0m"
        echo -e "\e[34mLet's try installing packages...\e[0m"
        install_packagegroup_gemini_best
        sleep 2
        apt update
        sleep 2
        apt-get -y upgrade
        sleep 5
        install_dependencies
        sleep 2
        ostende
    fi
else
    echo -e "\e[34m#######################\n#######################\n#######################\n#    Wait Please  ...   #\n#  Creat feed config  #\n#######################\n#######################\n#######################\e[0m"
    echo -e "\e[34mLet's try installing packages...\e[0m"
    install_packagegroup_gemini_best
    sleep 2
    apt update
    sleep 2
    apt-get -y upgrade
    sleep 5
    install_dependencies
    sleep 2
    ostende
fi

# Check and remove chunk
if [ -f /etc/apt/sources.list ]; then
    if grep -q "merlinfeed.boxpirates.to" /etc/apt/sources.list; then
        echo -e "\e[36mYou are using a Merlin image, let's clean duplicate lines\e[0m"
        remove_chunk
    fi
fi

exit