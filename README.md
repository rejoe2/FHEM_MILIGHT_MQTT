# FHEM_MILIGHT_MQTT
Perl module to use with Chris Mullins' ESP8266 Milight Hub
https://github.com/sidoh/esp8266_milight_hub

Needs before starting:
- running MQTT broker
- sidoh's Milight Bridge up and running. By default, newly created FHEM devices will use the same naming convention as the bridge.
First check, if communication between Bridge and MQTT broker is working. In Linux using mosquitto, you can test a console command like "mosquitto_sub -h <Server-IP> -d -t milight/updates/+/+/+".

Copy the module FHEM's module folder (by default: /opt/fhem/FHEM), check rights (owner:group) and define a first device:
  define <name> MQTT_MILIGHT_DEVICE <Bridge ID> <Slot> <Bridge Type> <Broker Name>
  Example: define myFirstMQTT_Milight_Device 0xAB12 2 rgbw myBroker
