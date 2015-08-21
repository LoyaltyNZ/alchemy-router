FROM alpine:3.2

MAINTAINER Graham Jenson <graham.jenson@loyalty.co.nz>

RUN apk-install python g++ gcc make git openssh
RUN npm install -g coffee-script 

RUN mkdir /www
WORKDIR /www
ADD . /www

# delete and reinstall packages
RUN npm install 

CMD coffee service.coffee

EXPOSE 8080