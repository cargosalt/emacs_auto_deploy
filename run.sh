#!/bin/sh
sed -i 's/\r$//' script.sh 2>/dev/null
chmod +x script.sh
./script.sh
