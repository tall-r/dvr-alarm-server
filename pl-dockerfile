FROM raspbian/stretch

LABEL Description="Alarm 2 MQTT Server for cheap IP cameras (perl)" Vendor="tall-r" Version="1.0"

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y perl libjson-perl make
RUN cpan -i Net::MQTT::Simple

COPY script/dvr-alarm-server.pl /usr/bin/dvr-alarm-server.pl

ENV MQTT_HOST localhost
ENV MQTT_PORT 1883
ENV MQTT_USER mqttUserName
ENV MQTT_PASSWD someMqttPassword

EXPOSE 15002

CMD /usr/bin/perl /usr/bin/dvr-alarm-server.pl
