#!/usr/bin/env bash
FILE=$(find /root/Wireguard -type f | shuf -n 1)
/usr/bin/wg-quick up $FILE
