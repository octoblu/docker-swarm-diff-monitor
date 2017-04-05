FROM octoblu/octoalpine-docker:1.12.6
MAINTAINER Octoblu <docker@octoblu.com>

ADD https://github.com/octoblu/json-escape/releases/download/v1.0.2/json-escape-linux-amd64 /bin/json-escape
RUN chmod +x /bin/json-escape

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY run.sh run.sh
COPY setup.sh setup.sh

CMD ["./run.sh"]
