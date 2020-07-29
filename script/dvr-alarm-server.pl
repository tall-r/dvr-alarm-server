#!/usr/bin/perl

#
# Simple log/alarm server receiving and printing to console remote dvr/camera events.
# future releases at https://gitlab.com/667bdrm/sofiactl
# Tested with:
#
# HJCCTV HJ-H4808BW
# http://www.aliexpress.com/item/Hybird-NVR-8chs-H-264DVR-8chs-onvif-2-3-Economical-DVR-8ch-Video-4-AUDIO-AND/1918734952.html
#
# PBFZ TCV-UTH200
# http://www.aliexpress.com/item/Free-shipping-2014-NEW-IP-camera-CCTV-2-0MP-HD-1080P-IP-Network-Security-CCTV-Waterproof/1958962188.html

# Add integration with MQTT by tall-r
# https://gist.github.com/tall-r/5ab5c76d4db97f35f371e4cc82b1dd7d

use strict;
#use warnings;

use IO::Socket;
use IO::Socket::INET;
use Sys::Syslog;
use Sys::Syslog qw(:DEFAULT setlogsock);
use Sys::Syslog qw(:standard :macros);
use Time::Local;
use JSON;
use Data::Dumper;

use Net::MQTT::Simple;

setlogsock("console");
openlog("dvr-alarm-server", "cons,pid", LOG_USER);


$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;

#my $mqttHost = "192.168.2.80";
#my $mqttPort = 1883;
#my $mqttUser = "user";
#my $mqttPassword = "some_password";

my $mqttHost = $ENV{MQTT_HOST};
my $mqttPort = $ENV{MQTT_PORT};
my $mqttUser = $ENV{MQTT_USER};
my $mqttPassword = $ENV{MQTT_PASSWD};


sub BuildPacket {
 my ($type, $params) = ($_[0], $_[1]);


 my @pkt_prefix_1;
 my @pkt_prefix_2;
 my @pkt_type;
 my $sid = 0;
 my $json = JSON->new;


 @pkt_prefix_1 = (0xff, 0x00, 0x00, 0x00);
 @pkt_prefix_2 =  (0x00, 0x00, 0x00, 0x00);

 if ($type eq 'login') {

   @pkt_type = (0x00, 0x00, 0xe8, 0x03);

 } elsif ($type eq 'info') {
   @pkt_type = (0x00, 0x00, 0xfc, 0x03);
 }

 $sid = hex($params->{'SessionID'});

 my $pkt_prefix_data =  pack('c*', @pkt_prefix_1) . pack('i', $sid) . pack('c*', @pkt_prefix_2). pack('c*', @pkt_type);

 my $pkt_params_data =  $json->encode($params);


 my $pkt_data = $pkt_prefix_data . pack('i', length($pkt_params_data)) . $pkt_params_data;

 return $pkt_data;

}

sub GetReplyHead {


 my $sock = $_[0];

 my @reply_head;

 my $data;

 for (my $i = 0; $i < 5; $i++) {
  $sock->recv($data, 4);
  $reply_head[$i]  = unpack('i', $data);

  print OUT $data;


  #print "$i: " . $reply_head[$i] . "\n";
 }

 my $reply_head = {
  Prefix1 => $reply_head[0],
  Prefix2 => $reply_head[1],
  Prefix3 => $reply_head[2],
  Prefix4 => $reply_head[3],
  Content_Length => $reply_head[4]
 };

 return $reply_head;
}


## params:
# serialID
# alarmType
# camIP
sub publishMQTT {
	my $serialID = $_[0];
	my $alarmType = $_[1];
#	my $camIP = $_[2];

	# Connect to broker
	my $mqtt = Net::MQTT::Simple->new($mqttHost . ":" . $mqttPort);

	# Depending if authentication is required, login to the broker
	if($mqttUser and $mqttPassword) {
	    $mqtt->login($mqttUser, $mqttPassword);
	}

	# Publish a message
	$mqtt->publish("camalarm/" . $serialID . "/event", $alarmType);

	$mqtt->disconnect();
}

my $sock = new IO::Socket::INET ( LocalHost => '0.0.0.0', LocalPort => '15002', Proto => 'tcp',  Listen => 1, Reuse => 1 ); die "Could not create socket: $!\n" unless $sock;

while (my ($client,$clientaddr) = $sock->accept()) {

 write_log("Connected from ".$client->peerhost());
 my $pid = fork();

 die "Cannot fork: $!" unless defined($pid);

 if ($pid == 0) {
        # Child process
		my $data = '';



        my $reply = GetReplyHead($client);

	# Client protocol detection
	$client->recv($data, $reply->{'Content_Length'});

	my $jdata = decode_json($data);

        #print Dumper decode_json($data);

	#print Dumper $jdata;

	my $event_type = $jdata->{Type};
	print "EVENT TYPE: " . $event_type . "\r\n";

	my $cam_addr = join '.', unpack 'C4', pack 'V', hex $jdata->{Address};

#	my $cam_int_addr = hex $cam_addr;
#	my $cam_ip = join '.', unpack 'C4', pack 'V', $cam_int_addr;

	#print $cam_addr . " -> " . $cam_int_addr . " -> " . $cam_ip . "\r\n";

	if ($event_type eq 'Alarm') {
		print "ALARM: " . $jdata->{Event} . "\r\n";
		print "CAM IP: " . $cam_addr . "\r\n";
		print "Serial: " . $jdata->{SerialID} . "\r\n";

		publishMQTT ($jdata->{SerialID}, $jdata->{Event}, $cam_addr);
       	}

	my $cproto = $data;

	# write_log($client->peerhost() . " proto = '$cproto'");

        exit(0);   # Child process exits when it is done.
 } # else 'tis the parent process, which goes back to accept()

}
close($sock);

sub write_log() {
 #syslog('info', $_[0]);
 my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time());
 my $timestamp = sprintf("%02d.%02d.%4d %02d:%02d:%02d",$mday,$mon+1,$year+1900,$hour,$min,$sec);

 print "$timestamp dvr-alarm-server[] " . $_[0] ."\n";

}
