FROM ruby:2.5.1

RUN apt-get update
RUN apt-get install -y --no-install-recommends apt-utils locales
RUN echo ja_JP.UTF-8 UTF-8 > /etc/locale.gen
RUN locale-gen
RUN update-locale LANG=ja_JP.UTF-8

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app
WORKDIR /usr/src/app
RUN bundle install

ENTRYPOINT ["bundle", "exec", "ruby", "app.rb"]
