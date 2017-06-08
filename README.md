# web-monitoring-db

This repository is the database and API underlying the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of monitored pages and revisions that have been made to them
- Allows other services to add new tracked pages/versions (we are currently focused on Versionista, but this database will soon host data from other sources, such as the Internet Archive)
- Provides an API to get that version data and allow analysts or other automated tools to annotate those versions with metadata


## Installation

1. Ensure you have Ruby 2.4.1+. 
    
    You can user [rbenv](https://github.com/rbenv/rbenv) to manage multiple Ruby versions
    
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

4. Clone this repo
5. If you don’t have the `bundler` Ruby gem, install it:

    ```sh
    $ gem install bundler
    ```

6. Wherever you cloned the repo, go to that directory and install dependencies:

    ```sh
    $ bundle install --without production
    ```

7. Set up your database

    First create users, databases and configure extensions:

    ```sh
    sudo -u postgres psql -c "CREATE USER wmdb_dev WITH PASSWORD 'wmdb_dev';"
    sudo -u postgres createdb -O wmdb_dev wmdb_dev -E utf-8
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' wmdb_dev
    sudo -u postgres psql -c 'CREATE EXTENSION IF NOT EXISTS "plpgsql";' wmdb_dev
    ```

    Then configure application's database and (optionally) import seed/sample data:

    ```sh
    $ bundle exec rake db:schema:load  # Populates the database with the current schema
    $ bundle exec rake db:seed         # Adds an admin user and sample data
    ```

    That will create a database, set up all the tables, create an admin user, and add some sample data. Make note of the admin user e-mail and password that are shown; you’ll need them to log in and create more users, import more data, or make annotations.

    If you don’t want to populate your DB with seed data (you've skipped `rake db:seed`) then you’ll still need to create an Admin user. You should not do this through the database since the password will need to be properly encrypted. Instead, open the rails console with `bundle exec rails console` and run the following:
    
    ```ruby
    User.create(
      email: '[your email address]',
      password: '[the password you want]',
      admin: true,
      confirmed_at: Time.now
    )
    ```

8. Start the server!

    ```sh
    $ bundle exec rails server
    ```

    You should now have a server running and can visit it at http://localhost:3000/. Open that up in a browser and go to town!

9. Bulk importing (and, in the future, potentially other features) make use of a
   Redis queue. If you plan to use any of these features, you must also start a
   Redis server and worker.

   Start redis:

   ```sh
   $ redis-server
   ```

   Start a worker:

   ```sh
   $ QUEUE=* VERBOSE=1 bundle exec rake environment resque:work
   ```

## Contributors

This project wouldn’t exist without a lot of amazing people’s help. Thanks to the following for all their contributions!

<!-- ALL-CONTRIBUTORS-LIST:START -->
| Contributions | Name |
| :---: | :---: |
| [💻](# "Code") [🚇](# "Infrastructure") [📖](# "Documentation") [💬](# "Answering Questions") [👀](# "Reviewer") | [Rob Brackett](https://github.com/Mr0grog) |
| [📖](# "Documentation") [👀](# "Reviewer") | [Dan Allan](https://github.com/danielballan) |
| [📖](# "Documentation") [📋](# "Organizer") | [Dawn Walker](https://github.com/dcwalk) |
| [📖](# "Documentation") [📋](# "Organizer") [📢](# "Talks") | [Matt Price](https://github.com/titaniumbones) |
| [📖](# "Documentation") | [Patrick Connolly](https://github.com/patcon) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Toly Rinberg](https://github.com/trinberg) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Andrew Bergman](https://github.com/ambergman) |
| [💻](# "Code") | [Robert Dalin](https://github.com/rdalin82) |
<!-- ALL-CONTRIBUTORS-LIST:END -->

(For a key to the contribution emoji or more info on this format, check out [“All Contributors.”](https://github.com/kentcdodds/all-contributors))


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/master/LICENSE) file for details.
