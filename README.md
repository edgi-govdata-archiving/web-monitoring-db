# web-monitoring-db

This repository is the database and API underlying the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of monitored pages and revisions that have been made to them
- Allows other services to add new tracked pages/versions (we are currently focused on Versionista, but this database will soon host data from other sources, such as the Internet Archive)
- Provides an API to get that version data and allow analysts or other automated tools to annotate those versions with metadata


## Installation

1. Ensure you have Ruby 2.4.1+

    You can use [rbenv](https://github.com/rbenv/rbenv) to manage multiple Ruby versions

2. Ensure you have PostgreSQL 9.5+

3. Ensure you have [Redis](https://redis.io)

    On OSX:

    ```sh
    $ brew install redis
    ```

    On Debian Linux:

    ```sh
    $ apt-get install redis
    ```

4. Ensure you have a JavaScript Runtime

    On OSX:

    You do not need to do anything.  Apple JavaScriptCore fulfills this dependency.

    On Debian Linux:

    ```sh
    $ apt-get install nodejs
    ```
    If you wish to use another runtime you can use one listed [here](https://github.com/rails/execjs/blob/master/README.md).

5. Clone this repo

6. If you don’t have the `bundler` Ruby gem, install it:

    ```sh
    $ gem install bundler
    ```

7. Wherever you cloned the repo, go to that directory and install dependencies:

    ```sh
    $ bundle install --without production
    ```

8. Copy the .env.example file to .env - this allows for easy configuration locally.

    ```sh
    $ cp .env.example .env
    ```

9. Set up your database. The simple way to do this is:

    ```sh
    $ bundle exec rake db:setup
    ```

    That will create a database, set up all the tables, create an admin user, and add some sample data. Make note of the admin user e-mail and password that are shown; you’ll need them to log in and create more users, import more data, or make annotations.

    If you’d like to do the setup manually see [manual postgres setup](#manual-postgres-setup) below.

    If you're getting error such as `FATAL: role "user" doesn't exist. Couldn't create database.` check [troubleshooting](#troubleshooting) below.

10. Start the server!

    ```sh
    $ bundle exec rails server
    ```

    You should now have a server running and can visit it at http://localhost:3000/. Open that up in a browser and go to town!

11. Bulk importing (and, in the future, potentially other features) make use of a Redis queue. If you plan to use any of these features, you must also start a Redis server and worker.

    Start redis:

    ```sh
    $ redis-server
    ```

    Start a worker:

    ```sh
    $ QUEUE=* VERBOSE=1 bundle exec rake environment resque:work
    ```


## Manual Postgres Setup

If you don’t want to populate your DB with seed data, want to manage creation of the database yourself, or otherwise manually do database setup, run any of the following commands as desired instead of `rake db:setup`:

```sh
$ bundle exec rake db:create       # Connects to Postgres and creates a new database
$ bundle exec rake db:schema:load  # Populates the database with the current schema
$ bundle exec rake db:seed         # Adds an admin user and sample data
```

If you skip `rake db:seed`, you’ll still need to create an Admin user. You should not do this through the database since the password will need to be properly encrypted. Instead, open the rails console with `rails console` and run the following:

```ruby
User.create(
  email: '[your email address]',
  password: '[the password you want]',
  admin: true,
  confirmed_at: Time.now
)
```


## Troubleshooting

If you are getting errors such as `FATAL: role "user" doesn't exist. Couldn't create database.` while running `rake db:setup` or `rake db:create` then it may mean that your database is password protected. There are two ways to setup required databases:

1. (Recommended) Create users and databases manually

    ```sh
    sudo -u postgres psql -c "CREATE USER \"web-monitoring-db_development\" WITH PASSWORD 'wmdb';"
    sudo -u postgres createdb -O web-monitoring-db_development web-monitoring-db_development -E utf-8
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' web-monitoring-db_development
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "pgcrypto";' web-monitoring-db_development
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "plpgsql";' web-monitoring-db_development
    ```

    and then set `DATABASE_URL` environment variable to point to the development database:

    ```sh
    export DATABASE_URL=postgres://web-monitoring-db_development:wmdb@localhost/web-monitoring-db_development
    ```

    You can put this line in your `~/.bashrc` or `~/.profile` file not to type it each time you open terminal.

    Required databases exist, now continue with loading schema.

2. Loosen local Postgres database security to allow local users without password

    You have to edit [pg_hba.conf](https://www.postgresql.org/docs/9.6/static/auth-pg-hba-conf.html) config file (`/etc/postgresql/9.6/main/pg_hba.conf` on Unix) and add or update authorization line for local logins from `md5` to `trust`:

    ```
    # "local" is for Unix domain socket connections only
    local   all             all                                     trust
    # IPv4 local connections:
    host    all             all             127.0.0.1/32            trust
    ```

    Create Postgres superuser that will link to your account:
    ```
    sudo -u postgres createuser `whoami` -ds
    ```

    Now `bundle exec rake db:setup` command should work.

## Docker

The Dockerfile runs the rails server on port 3000 in the container. To build
and run:

```
docker build -t db . -e <ENVIRONMENT VARIABLES>
docker run -p 3000:3000 db
```

Point your browser or ``curl`` at ``http://localhost:3000``.

## Contributors

This project wouldn’t exist without a lot of amazing people’s help. Thanks to the following for all their contributions!

<!-- ALL-CONTRIBUTORS-LIST:START -->
| Contributions | Name |
| ----: | :---- |
| [📖](# "Documentation") [👀](# "Reviewer") | [Dan Allan](https://github.com/danielballan) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Andrew Bergman](https://github.com/ambergman) |
| [💻](# "Code") [🚇](# "Infrastructure") [📖](# "Documentation") [💬](# "Answering Questions") [👀](# "Reviewer") | [Rob Brackett](https://github.com/Mr0grog) |
| [📖](# "Documentation") | [Patrick Connolly](https://github.com/patcon) |
| [💻](# "Code") | [Robert Dalin](https://github.com/rdalin82) |
| [💻](# "Code") | [Kate Donaldson](https://github.com/katelovescode) |
| [📖](# "Documentation") | [Michael Hardy](https://github.com/michardy) |
| [💻](# "Code") | [Kasper Holbek Jensen](https://github.com/kholbekj) |
| [💻](# "Code") | [Shishir Joshi](https://github.com/shishir127) |
| [💻](# "Code") [📖](# "Documentation") | [Krzysztof Madejski](https://github.com/KrzysztofMadejski) |
| [📖](# "Documentation") [📋](# "Organizer") [📢](# "Talks") | [Matt Price](https://github.com/titaniumbones) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Toly Rinberg](https://github.com/trinberg) |
| [🚇](# "Infrastructure")  | [Frederik Spang](https://github.com/frederikspang) |
| [💻](# "Code") | [Max Tedford](https://github.com/maxtedford) |
| [📖](# "Documentation") [📋](# "Organizer") | [Dawn Walker](https://github.com/dcwalk) |
<!-- ALL-CONTRIBUTORS-LIST:END -->

(For a key to the contribution emoji or more info on this format, check out [“All Contributors.”](https://github.com/kentcdodds/all-contributors))


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/master/LICENSE) file for details.
