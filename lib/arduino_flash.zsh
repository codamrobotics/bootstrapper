#!/bin/zsh
source /opt/bootstrapper.cfg

/usr/bin/ard-reset-arduino $FLASH_DEV || exit 1

/usr/bin/avrdude -q -V -p atmega2560 -C /usr/share/arduino/hardware/tools/avr/../avrdude.conf -D -c stk500v2 -b 115200 -P $FLASH_DEV -U flash:w:$FLASH_FILE:i
