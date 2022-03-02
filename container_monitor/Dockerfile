FROM alpine:3.15

WORKDIR /opt/monitor

RUN apk add --update bash docker openrc
RUN rc-update add docker boot

CMD [ "/bin/bash", "/opt/monitor/scripts/entrypoint.sh" ]
