FROM alpine:3.3

MAINTAINER Graham Jenson <graham.jenson@loyalty.co.nz>

RUN apk update
RUN apk add nodejs python g++ gcc make
RUN npm install -g coffee-script

RUN mkdir /www
WORKDIR /www

COPY ./package.json /www/
RUN npm install

ADD . /www

CMD coffee service.coffee


EXPOSE 8080