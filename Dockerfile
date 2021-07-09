FROM ruby:2.5

WORKDIR /usr/src/activerecord_materialize_adapter
ADD . /usr/src/activerecord_materialize_adapter

RUN bundle install