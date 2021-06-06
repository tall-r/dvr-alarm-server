import socketserver
import json
import datetime
import os
import sys
import paho.mqtt.publish as mqtt

class Log:
    is_debug = False
    def log_event(self, message, message_kind=''):
        pass
    
    def log_info(self, message):
        self.log_event(message, "INFO")
    
    def log_error(self, message):
        self.log_event(message, "ERROR")
    
    def log_debug(self, message):
        if self.is_debug:
            self.log_event(message, "DEBUG")
    

class ConsoleLog(Log):
    def log_event(self, message, message_kind=''):
        if message_kind == '':
            print('{}\t{}'.format(datetime.datetime.now().isoformat(), message))
        else:
            print('{}\t{}\t{}'.format(datetime.datetime.now().isoformat(), message_kind, message))
    


class MQTTPublisher:
    mqttHost = ''
    mqttPort = 1883

    mqttUser = ''
    mqttPass = ''

    def __init__ (self, host, port, user, passwd):
        self.mqttHost = host
        self.mqttPort = port
        self.mqttUser = user
        self.mqttPass = passwd

    def publish(self, serialID, event):
        #log = ConsoleLog()
        LOG.log_info('Publish MQTT')
        LOG.log_debug("MQTT_HOST=[{}] MQTT_PORT=[{}] MQTT_USER=[{}]".format(self.mqttHost, self.mqttPort, self.mqttUser))
        
        auth_data = None
        if (self.mqttUser and self.mqttPass) :
            LOG.log_debug('Set credentials ({})'.format(self.mqttUser))
            auth_data = {'username':self.mqttUser, 'password':self.mqttPass }

        LOG.log_info('Connecting to {}:{}'.format(self.mqttHost, self.mqttPort))
        topic = 'camalarm/{}/event'.format(serialID)
        LOG.log_info('Publish topic {}:{}'.format(topic,event))
        mqtt.single(topic = topic, payload = event, retain = False, hostname = self.mqttHost, port = self.mqttPort, auth = auth_data, tls = None)



class AlarmServerHandler(socketserver.BaseRequestHandler):

    def handle(self):
        #log = ConsoleLog()

        LOG.log_info('Client connected from {}'.format(self.client_address[0]))

        header = self.request.recv(8)

        self.data = self.request.recv(1024).strip()
        data = bytes(self.data)[12:]
#        print( 'BIN data: {}'.format(data) )

#        payload = str(self.data, 'ascii', 'ignore').strip()
        payload = data.decode('ascii')

        LOG.log_info ("Payload: {}".format(payload))

        json_data = json.loads(payload)
        event_type = json_data.get('Type')
        event = json_data.get('Event')
        if "Channel" in json_data:
          serialID = str(json_data.get('SerialID')) + "/" + str(json_data.get('Channel'))
        else:
          serialID = json_data.get('SerialID')

        LOG.log_info ("{} Serial: {}; Event: {}".format(event_type, serialID, event))

        if event_type == 'Alarm' :
            #LOG.log_event("Publish MQTT")
            #m = MQTTPublisher('192.168.2.80',1883,'broker', 'BrokerUserMQTT')
            #LOG.log_debug("MQTT_HOST=[{}] MQTT_PORT=[{}] MQTT_USER=[{}]".format(MQTT_HOST, MQTT_PORT, MQTT_USER))
            #m = MQTTPublisher(MQTT_HOST, MQTT_PORT, MQTT_USER, MQTT_PASSWD)
            #m.publish(serialID, event)
            publisher.publish(serialID, event)


LOG = ConsoleLog()
#LOG.is_debug = True

publisher = None
#MQTT_HOST = ''
#MQTT_PORT = 1883
#MQTT_USER = ''
#MQTT_PASSWD = ''

version = '0.1'

def main():
    HOST, PORT = '0.0.0.0', 15002

    global publisher
#    global MQTT_HOST
#    global MQTT_PORT
#    global MQTT_USER
#    global MQTT_PASSWD

    LOG.log_event('****** dvr-alaram-server (Python) v.{} ******'.format(version))

    MQTT_HOST = os.environ.setdefault('MQTT_HOST', '')
    MQTT_PORT = int(os.environ.setdefault('MQTT_PORT', '1883'))
    MQTT_USER = os.environ.setdefault('MQTT_USER', '')
    MQTT_PASSWD = os.environ.setdefault('MQTT_PASSWD', '')

    LOG.log_debug("MQTT_HOST=[{}] MQTT_PORT=[{}] MQTT_USER=[{}]".format(MQTT_HOST, MQTT_PORT, MQTT_USER))

    if MQTT_HOST == '':
        LOG.log_error("No MQTT_HOST is specified.")
        sys.exit(1)

    publisher = MQTTPublisher(MQTT_HOST, MQTT_PORT, MQTT_USER, MQTT_PASSWD)

    server = socketserver.TCPServer((HOST, PORT), AlarmServerHandler)

    server.serve_forever()

    server.server_close()


if __name__ == "__main__":
    main()
