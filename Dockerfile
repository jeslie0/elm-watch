FROM ubuntu:latest
USER root
WORKDIR /home/app
RUN apt-get update
RUN apt-get -y install curl gnupg make g++ gcc
RUN curl -sL https://deb.nodesource.com/setup_16.x  | bash -
RUN apt-get -y install nodejs
