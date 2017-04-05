FROM octoblu/octoalpine-docker:1.12.6
MAINTAINER Octoblu <docker@octoblu.com>

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

CMD ["docker-swarm-diff"]
