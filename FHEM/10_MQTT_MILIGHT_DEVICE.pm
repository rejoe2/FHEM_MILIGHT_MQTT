##############################################
#
# fhem bridge to mqtt (see http://mqtt.org)
#
# Copyright (C) 2017 Stephan Eisler
# Copyright (C) 2014 - 2016 Norbert Truchsess
# Modified 2017 for sidoh ESP Milight Hub by lufi@FHEM-Forum: https://forum.fhem.de/index.php/topic,75144.msg674649.html#msg674649
# Extended version by Beta-User@FHEM-Forum 2018
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id: 10_MQTT_MILIGHT_DEVICE.pm 1 2018-03-23 12:00:00Z Beta-User $
#
##############################################

use strict;
use warnings;

my %gets = (
  "version"   => "",
);

sub MQTT_MILIGHT_DEVICE_Initialize($) {

  my $hash = shift @_;

  # Consumer
  $hash->{DefFn}    = "MQTT::MILIGHT::DEVICE::Define";
  $hash->{UndefFn}  = "MQTT::MILIGHT::Client_Undefine";
  $hash->{SetFn}    = "MQTT::MILIGHT::DEVICE::Set";
  $hash->{AttrFn}   = "MQTT::MILIGHT::DEVICE::Attr";
  $hash->{OnMessageFn} = "MQTT::MILIGHT::DEVICE::onmessage";
  $hash->{AttrList} =
    "IODev ".
    "qos:".join(",",keys %MQTT::qos)." ".
    "retain:0,1 ".
    "sendJson:0,1 ".
    "publishSet ".
    "publishSet_.* ".
    "subscribeReading_.* ".
    "autoSubscribeReadings ".
    "useSetExtensions:1,0 ".
	$main::readingFnAttributes;
    
	FHEM_colorpickerInit();
    main::LoadModule("MQTT");
	
}

package MQTT::MILIGHT::DEVICE;

use strict;
use warnings;
use GPUtils qw(:all);

use Net::MQTT::Constants;
use SetExtensions qw/ :all /;
use JSON::XS;

my %dim_values = (
   0 => "dim_00",
   1 => "dim_10",
   2 => "dim_20",
   3 => "dim_30",
   4 => "dim_40",
   5 => "dim_50",
   6 => "dim_60",
   7 => "dim_70",
   8 => "dim_80",
   9 => "dim_90",
  10 => "dim_100",
);

BEGIN {
  MQTT->import(qw(:all));

  GP_Import(qw(
    CommandDeleteReading
    CommandAttr
    readingsSingleUpdate
    Log3
	SetExtensions
	SetExtensionsCancel
    fhem
    defs
    AttrVal
    ReadingsVal
  ))
};

sub Define() {
  my ( $hash, $def,$bridgeID,$slot,$bridgeType ) = @_;
  $hash->{sets} = {};
  MQTT::Client_Define($hash,$def);
  my $name = $def;
  CommandAttr(undef,"$hash->{NAME} webCmd status:brightness:hue:command") unless (AttrVal($name,"webCmd",undef));
  CommandAttr(undef,"$hash->{NAME} widgetOverride command:uzsuSelectRadio,Weiss,Nacht hue:colorpicker,HUE,0,1,359 brightness:colorpicker,BRI,0,1,255 status:uzsuToggle,OFF,ON") unless (AttrVal($name,"widgetOverride",undef));
  CommandAttr(undef,"$hash->{NAME} devStateIcon ON:on:off OFF:off:on") unless (AttrVal($name,"devStateIcon",undef));
  unless (AttrVal($name,"devStateIcon",undef)){
		my $dynicon = getIconCode($name,$bridgeType);
		CommandAttr(undef,"$hash->{NAME} devStateIcon $dynicon") ;
	}
  CommandAttr(undef,"$hash->{NAME} eventMap /set_white:Weiss/ /night_mode:Nacht/ /white_mode:white/ /status ON:on/ /status OFF:off/") unless (AttrVal($name,"eventMap",undef));
  CommandAttr(undef,"$hash->{NAME} subscribeReading_status milight/state/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"subscribeReading_status",undef));
  unless (AttrVal($name,"subscribeReading_update",undef)) {
	my $subscription = "milight/updates/$bridgeID/$bridgeType/$slot" unless $slot;
	my $subscription = "milight/updates/$bridgeID/$bridgeType/$slot,milight/updates/$bridgeID/$bridgeType/0" if $slot;
	CommandAttr(undef,"$hash->{NAME} subscribeReading_update $subscription") unless (AttrVal($name,"subscribeReading_update",undef));
  }	
  CommandAttr(undef,"$hash->{NAME} icon light_control") unless (AttrVal($name,"icon",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_brightness milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_brightness",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_command set_white level_up level_down next_mode previous_mode temperature_up temperature_down milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_command",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_hue milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_hue",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_level milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_level",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_state ON OFF milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_state",undef));
  CommandAttr(undef,"$hash->{NAME} publishSet_status ON OFF milight/$bridgeID/$bridgeType/$slot") unless (AttrVal($name,"publishSet_status",undef));
  CommandAttr(undef,"$hash->{NAME} stateFormat state") unless (AttrVal($name,"stateFormat",undef));

  
	#{my $power=ReadingsVal($name,"status","OFF");if($power eq "OFF"){Color::devStateIcon($name,"status",undef,"status");}else{Color::devStateIcon($name,"dimmer",undef,"bright")}}' if (!defined($attr{$name}{devStateIcon}) && defined($model) && ($model eq "mono" || $model eq "desklamp"));
	#$attr{$name}{devStateIcon} = '{my $power=ReadingsVal($name,"status","OFF");if($power eq "OFF"){Color::devStateIcon($name,"status",undef,"status");}else{Color::devStateIcon($name,"dimmer",undef,"bright")}}' if (!defined($attr{$name}{devStateIcon}) && defined($model) && ($model eq "mono" || $model eq "desklamp"));
    
return undef;
};

sub Set($$$@) {
  my ($hash,$name,$command,@values) = @_;
  return "Need at least one parameters" unless defined $command;
  my $msgid;
  my $mark=0;
  if($command ne '?') {
	Log3($hash->{NAME},5, "sendJson: $hash->{'.sendJson'}");
    my $value = join " ",@values;
    $value =~ s/^\s+|\s+$//g;
    #$json_text = encode_json ($perl_scalar ); #https://www.tutorialspoint.com/json/json_perl_example.htm
    #my $jsonvalue = encode_json ($command => $value); # So?!?
    #$msgid = send_publish($hash->{IODev}, topic => $hash->{publishSets}->{$command}->{topic}, message => $jsonvalue, qos => $hash->{qos}, retain => $hash->{retain});
    $msgid = send_publish($hash->{IODev}, topic => $hash->{publishSets}->{$command}->{topic}, message => "{\"$command\":\"$value\"}", qos => $hash->{qos}, retain => $hash->{retain});
    $mark=1
  }
  if(!$mark) {
    return "Unknown argument $command, choose one of " . join(" ", map {$hash->{sets}->{$_} eq "" ? $_ : "$_:".$hash->{sets}->{$_}} sort keys %{$hash->{sets}})
  }
  $hash->{message_ids}->{$msgid}++ if defined $msgid;
  readingsSingleUpdate($hash,"transmission-state","outgoing publish sent",1);
  return undef;
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute =~ /^subscribeReading_(.+)/ and do {
      if ($command eq "set") {
        unless (defined $hash->{subscribeReadings}->{$value} and $hash->{subscribeReadings}->{$value} eq $1) {
          unless (defined $hash->{subscribeReadings}->{$value}) {
            client_subscribe_topic($hash,$value);
          }
          $hash->{subscribeReadings}->{$value} = $1;
        }
      } else {
        foreach my $topic (keys %{$hash->{subscribeReadings}}) {
          if ($hash->{subscribeReadings}->{$topic} eq $1) {
            client_unsubscribe_topic($hash,$topic);
            delete $hash->{subscribeReadings}->{$topic};
            CommandDeleteReading(undef,"$hash->{NAME} $1");
            last;
          }
        }
      }
      last;
    };
    $attribute eq "sendJson" and do {
      if ($command eq "set") {
        $hash->{'.sendJson'} = $value;
      } else {
        if (defined $hash->{'.sendJson'}) {
          delete $hash->{'.sendJson'};
        }
      }
      last;
    };    
    $attribute eq "autoSubscribeReadings" and do {
      if ($command eq "set") {
        unless (defined $hash->{'.autoSubscribeTopic'} and $hash->{'.autoSubscribeTopic'} eq $value) {
          if (defined $hash->{'.autoSubscribeTopic'}) {
            client_unsubscribe_topic($hash,$hash->{'.autoSubscribeTopic'});
          }
          $hash->{'.autoSubscribeTopic'} = $value;
          $hash->{'.autoSubscribeExpr'} = topic_to_regexp($value);
          client_subscribe_topic($hash,$value);
        }
      } else {
        if (defined $hash->{'.autoSubscribeTopic'}) {
          client_unsubscribe_topic($hash,$hash->{'.autoSubscribeTopic'});
          delete $hash->{'.autoSubscribeTopic'};
          delete $hash->{'.autoSubscribeExpr'};
        }
      }
      last;
    };
    $attribute =~ /^publishSet(_?)(.*)/ and do {
      if ($command eq "set") {
        my @values = split ("[ \t]+",$value);
        my $topic = pop @values;
        $hash->{publishSets}->{$2} = {
          'values' => \@values,
          topic    => $topic,
        };
        if ($2 eq "") {
          if(@values) {
            foreach my $set (@values) {
              $hash->{sets}->{$set}="";
              my($setname,@restvalues) = split(":",$set);
              if(@restvalues) {
                $hash->{publishSets}->{$setname} = {
                  'values' => \@restvalues,
                  topic    => $topic,
                };
              }
            }
          } else {
            $hash->{sets}->{""}="";
          }
        } else {
          $hash->{sets}->{$2}=join(",",@values);
        }
      } else {
        if ($2 eq "") {
          foreach my $set (@{$hash->{publishSets}->{$2}->{'values'}}) {
            delete $hash->{sets}->{$set};
          }
        } else {
          CommandDeleteReading(undef,"$hash->{NAME} $2");
          delete $hash->{sets}->{$2};
        }
        delete $hash->{publishSets}->{$2};
      }
      last;
    };
    client_attr($hash,$command,$name,$attribute,$value);
  }
}

sub onmessage($$$) {
  my ($hash,$topic,$message) = @_;
  if (defined (my $reading = $hash->{subscribeReadings}->{$topic})) {
    Log3($hash->{NAME},5,"calling readingsBulkUpdate($hash->{NAME},$reading,$message,1");
    my $jsonlist = decode_json($message);
    while( my ($key,$value) = each %{$jsonlist} ) {
      readingsSingleUpdate($hash,$key,$value,1);
      Log3($hash->{NAME},5,"calling readingsSingleUpdate($hash->{NAME} (loop),$key,$value,1");
    }
  } elsif ($topic =~ $hash->{'.autoSubscribeExpr'}) {
    Log3($hash->{NAME},5,"calling readingsSingleUpdate($hash->{NAME},$1,$message,1");
    CommandAttr(undef,"$hash->{NAME} subscribeReading_$1 $topic");
    readingsSingleUpdate($hash,$1,$message,1);
  }
}

sub getIconCode($$) {
  my($hash,$ledtype) = @_;
  my $name = $hash->{NAME};
  my $number = ReadingsVal($name,"brightness","255")/255*10;
  my $s = $dim_values{sprintf("%.0f", $number)};
  # Return SVG coloured icon with toggle as default action
  my $rgbvalue = "ABCDEF";
  return ".*:light_light_$s@#$rgbvalue ON:on:off OFF:off:on" if ($ledtype eq "rgbw" || $ledtype eq "rgb");
  # Return SVG icon with toggle as default action (for White bulbs)
  return ".*:light_light_$s: ON:on:off OFF:off:on";
}

1;

=pod
=item [device]
=item summary MQTT_MILIGHT_DEVICE acts as a fhem-device that is mapped to mqtt-topics. This is a version adopted to the ESP-Milight-Hub provided by Chris Mullins. Details on this project see https://github.com/sidoh/esp8266_milight_hub
=begin html

<a name="MQTT_MILIGHT_DEVICE"></a>
<h3>MQTT_MILIGHT_DEVICE</h3>
<ul>
  <p>acts as a fhem-device that is mapped to <a href="http://mqtt.org/">mqtt</a>-topics provided by a ESP8266-Milight-Bridge.</p>
  <p>requires a <a href="#MQTT">MQTT</a>-device as IODev<br/>
     Note: this module is based on <a href="https://metacpan.org/pod/distribution/Net-MQTT/lib/Net/MQTT.pod">Net::MQTT</a> which needs to be installed from CPAN first.</p>
  <a name="MQTT_MILIGHT_DEVICEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MQTT_MILIGHT_DEVICE &lt;Bridge ID&gt; &lt;Slot&gt; &lt;Bridge Type&gt;</code><br/>
       Specifies the MQTT-Milight device.</p>
  </ul>
  <p>Example: <code>define myFirstMQTT_Milight_Device 0xAB12 2 rgbw</code><br/>
		would create a device on channel 2, sending and receiving commands using Milight ID 0xAB12 and also listen to codes sent by a remote to the entire group</br>
  
  <a name="MQTT_MILIGHT_DEVICEset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; &lt;command&gt;</code><br/>
         sets reading 'state' and others and publishes the command to topic configured via attr publishSet</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; &lt;h;reading&gt; &lt;value&gt;</code><br/>
         sets reading &lt;h;reading&gt; and publishes the command to topic configured via attr publishSet_&lt;h;reading&gt;</p>
    </li>
  </ul>
  <a name="MQTT_MILIGHT_DEVICEattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; publishSet [&lt;commands&gt;] &lt;topic&gt;</code><br/>
         configures set commands that may be used to both set reading 'state' and publish to configured topic</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; publishSet_&lt;reading&gt; [&lt;values&gt;] &lt;topic&gt;</code><br/>
         configures reading that may be used to both set 'reading' (to optionally configured values) and publish to configured topic</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; autoSubscribeReadings &lt;topic&gt;</code><br/>
         specify a mqtt-topic pattern with wildcard (e.c. 'myhouse/kitchen/+') and MQTT_MILIGHT_DEVICE automagically creates readings based on the wildcard-match<br/>
         e.g a message received with topic 'myhouse/kitchen/temperature' would create and update a reading 'temperature'</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; subscribeReading_&lt;reading&gt; &lt;topic&gt;</code><br/>
         mapps a reading to a specific topic. The reading is updated whenever a message to the configured topic arrives</p>
    </li>
  </ul>
</ul>

=end html
=cut
