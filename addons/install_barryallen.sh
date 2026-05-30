#!/bin/sh

PACKAGE="enigma2-plugin-extensions-barryallen_12.91-r2_all.deb"
URL="https://raw.githubusercontent.com/eliesatpanelgrid/dream_os/main/addons/${PACKAGE}"
TMP="/tmp/${PACKAGE}"

echo "================================="
echo " Installing Barry Allen 12.91-r2"
echo "================================="

rm -f "$TMP"

wget --no-check-certificate -O "$TMP" "$URL"
if [ $? -ne 0 ]; then
    echo "Download failed!"
    exit 1
fi

dpkg -i "$TMP"
if [ $? -ne 0 ]; then
    echo "Fixing dependencies..."
    apt-get update
    apt-get -f install -y
    dpkg -i "$TMP"
fi

rm -f "$TMP"

echo ""
echo "Installation completed."
sleep 2

systemctl restart enigma2 2>/dev/null || killall -9 enigma2