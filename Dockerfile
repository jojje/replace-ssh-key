FROM ruby:2.3-slim

RUN apt-get update \
 && apt-get install -y openssh-client \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && mkdir /work

WORKDIR /work

COPY ./replace-ssh-key.rb /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/replace-ssh-key.rb"]

