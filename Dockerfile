FROM octoblu/octoalpine-docker:1.12.6
MAINTAINER Octoblu <docker@octoblu.com>

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY run.sh run.sh
COPY setup.sh setup.sh

CMD ["./run.sh"]
