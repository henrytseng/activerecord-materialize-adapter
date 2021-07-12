FROM ruby:2.5

WORKDIR /usr/src
ADD . /usr/src

RUN bundle install --path=.bundle
