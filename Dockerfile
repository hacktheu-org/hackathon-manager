FROM ruby:2.6

WORKDIR /opt/hm

RUN apt-get update -qq && apt-get install nodejs -y

# Copy dependency files.
COPY Gemfile .
COPY Gemfile.lock .

# Install dependencies.
RUN bundle install

# Copy over the rest of the files.
COPY . .

CMD ["sh", "-c", "bin/rails s"]
