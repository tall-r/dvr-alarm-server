FROM raspbian/stretch

LABEL Description="Alarm 2 MQTT Server for cheap IP cameras (python)" Vendor="tall-r" Version="0.1"

RUN apt-get update && apt-get upgrade -y
RUN apt-get remove python -y && apt-get install python3 python3-pip
RUN python3.5 -m pip install --upgrade pip && python3.5 -m pip install Flask paho-mqtt

COPY scripts/dvr-alarm-server.py /usr/bin/dvr-alarm-server.py

ENV MQTT_HOST 192.168.2.80
ENV MQTT_PORT 1883
ENV MQTT_USER mqttUserName
ENV MQTT_PASSWD someMqttPassword

EXPOSE 15002

CMD /usr/bin/python3.5 /usr/bin/dvr-alarm-server.py
