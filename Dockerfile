FROM ubuntu:22.04
RUN apt update
RUN apt install xxd
COPY ./strip_psv.sh /usr/bin
CMD strip_psv.sh
