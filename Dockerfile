FROM ruby:2-alpine

WORKDIR /app
COPY . /app

RUN bundle install

CMD ./time_to_clear.rb
