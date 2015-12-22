FROM alpine:3.2

MAINTAINER Graham Jenson <graham.jenson@loyalty.co.nz>

RUN apk update
RUN apk add nodejs python g++ gcc make
RUN npm install -g alchemy-router

CMD alchemy-router

EXPOSE 8080