# web-monitoring-db

This repository is the database and API underlying the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of monitored pages and revisions that have been made to them
- Allows other services to add new tracked pages/versions (we are currently focused on Versionista, but this database will soon host data from other sources, such as the Internet Archive)
- Provides an API to get that version data and allow analysts or other automated tools to annotate those versions with metadata


## Installation

1. Ensure you have Ruby 2.4.1+.

    You can use [rbenv](https://github.com/rbenv/rbenv) to manage multiple Ruby versions

2. Ensure you have PostgreSQL 9.5+. If you are on MacOS, we recommend [Postgres.app](https://postgresapp.com). It makes running multiple versions of PostgreSQL much simpler and gives you easy access to start and stop your databases.

3. Ensure you have [Redis](https://redis.io)

    On MacOS:

    ```sh
    $ brew install redis
    ```

    On Debian Linux:

    ```sh
    $ apt-get install redis
    ```

4. Ensure you have a JavaScript Runtime

    On MacOS:

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

    Take a moment to look through the variables here and change any that make sense for your local environment. If you need set variables differently when running tests, make a `.env.test` file that has your test-specific variables.

9. Set up your database.

    - If your Postgres install trusts local users and you have a superuser (this is the normal situation with Postgres.app), run:

        ```sh
        $ bundle exec rake db:setup
        ```

        That will create a database, set up all the tables, create an admin user, and add some sample data. Make note of the admin user e-mail and password that are shown; you’ll need them to log in and create more users, import more data, or make annotations.

        If you’d like to do the setup manually or don’t want sample data, see [manual postgres setup](#manual-postgres-setup) below.

    - If your Postgres install has a superuser, but doesn't trust local connections, you'll need to configure database credentials in `.env`. Find the line for `DATABASE_URL` in your `.env` file, uncomment it, and fill it in with your username and password. Make another file named `.env.test` and copy that line, but change the database line at the end to configure your test database. Then run the same command as above:

        ```sh
        $ bundle exec rake db:setup
        ```

        If you’d like to do the setup manually or don’t want sample data, see [manual postgres setup](#manual-postgres-setup) below.

    - If you’d like to configure your Postgres DB to be more secure and require a non-superuser for your databases, you’ll need to do a little more work:

        1. Log into `psql` and create a new user for your databases. Change the username and password to whatever you’d like:

            ```sql
            CREATE USER wm_dev_user PASSWORD 'wm_dev_password';
            ```

        2. (Still in `psql`) Create a development and a test database:

            ```sql
            -- Development database
            $ CREATE DATABASE web_monitoring_dev ENCODING 'utf-8' OWNER wm_dev_user;
            $ \c web_monitoring_dev
            $ CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            $ CREATE EXTENSION IF NOT EXISTS "pgcrypto";
            $ CREATE EXTENSION IF NOT EXISTS "plpgsql";
            $ CREATE EXTENSION IF NOT EXISTS "citext";
            -- Repeat for test database
            $ CREATE DATABASE web_monitoring_test ENCODING 'utf-8' OWNER wm_dev_user;
            $ \c web_monitoring_test
            $ CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            $ CREATE EXTENSION IF NOT EXISTS "pgcrypto";
            $ CREATE EXTENSION IF NOT EXISTS "plpgsql";
            $ CREATE EXTENSION IF NOT EXISTS "citext";
            ```

        3. Exit the `psql` console and open your `.env` file. Find the line for `DATABASE_URL` in your `.env` file, uncomment it, and fill it in with your credentials and database name from above:

            ```sh
            DATABASE_URL=postgres://wm_dev_user:wm_dev_password@localhost:5432/web_monitoring_dev
            ```

            Make a `.env.test` file and set the same value there, but with the name of your test database:

            ```sh
            DATABASE_URL=postgres://wm_dev_user:wm_dev_password@localhost:5432/web_monitoring_test
            ```

        4. Set up all the tables and test data in your DB by running:

            ```sh
            # Set up tables, indexes, and general database schema:
            $ bundle exec rake db:schema:load
            # Add sample data and an admin user:
            $ bundle exec rake db:seed
            ```

            For more on this last step, see [manual postgres setup](#manual-postgres-setup) below.

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


## Docker

The Dockerfile runs the rails server on port 3000 in the container. To build
and run:

```
docker build --target rails-server -t envirodgi/db-rails-server .
docker build --target import-worker -t envirodgi/db-import-worker .
docker run -p 3000:3000 envirodgi/db-rails-server -e <ENVIRONMENT VARIABLES> .
docker run -p 6379:6379 envirodgi/db-import-worker -e <ENVIRONMENT VARIABLES> .
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
