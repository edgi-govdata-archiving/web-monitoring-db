# web-monitoring-db

---
:information_source: **Welcome Mozilla Global Sprinters!** :wave: :tada: :confetti_ball:
Thank you for helping out with our project, please take a moment to read our [Code of Conduct](https://github.com/edgi-govdata-archiving/overview/blob/master/CONDUCT.md) and project-specific [Contributing Guidelines](https://github.com/edgi-govdata-archiving/web-monitoring/blob/master/CONTRIBUTING.md).

:globe_with_meridians: We will be sprinting in-person at the [Toronto Mozilla Offices](https://ti.to/Mozilla/global-sprint-toronto), but remote contributors are more than welcome! Most of our team is based in the [Eastern Time Zone (ET)](https://en.wikipedia.org/wiki/Eastern_Time_Zone) or [Pacific Time Zone (PT)](https://en.wikipedia.org/wiki/Pacific_Time_Zone).

We are looking forward to working together! You can get started by:

- :speech_balloon: Joining the [Archivers Slack](https://archivers-slack.herokuapp.com/) and join `#dev` and `#dev-webmonitoring`
- :clipboard: Reviewing the [**web-monitoring**](https://github.com/edgi-govdata-archiving/web-monitoring) repo, in particular read about the [project architecture](https://github.com/edgi-govdata-archiving/web-monitoring#architecture)
- :bookmark_tabs: Looking at our issue tracker, for the global sprint we are targeting `mozsprint` or `first-timer` issues:

   | Repo | Issues |
   |------|--------|
   | [**web-monitoring**](https://github.com/edgi-govdata-archiving/web-monitoring) | [`mozsprint`](https://github.com/edgi-govdata-archiving/web-monitoring/issues?q=is%3Aissue+is%3Aopen+label%3Amozsprint), [`first-timer`](https://github.com/edgi-govdata-archiving/web-monitoring/issues?q=is%3Aissue+is%3Aopen+label%3Afirst-timer) |
   | [**web-monitoring-processing**](https://github.com/edgi-govdata-archiving/web-monitoring-processing) | [`mozsprint`](https://github.com/edgi-govdata-archiving/web-monitoring-processing/issues?q=is%3Aissue+is%3Aopen+label%3Amozsprint), [`first-timer`](https://github.com/edgi-govdata-archiving/web-monitoring-processing/issues?q=is%3Aissue+is%3Aopen+label%3Afirst-timer) |
   | [**web-monitoring-ui**](https://github.com/edgi-govdata-archiving/web-monitoring-ui) | [`mozsprint`](https://github.com/edgi-govdata-archiving/web-monitoring-ui/issues?q=is%3Aissue+is%3Aopen+label%3Amozsprint), [`first-timer`](https://github.com/edgi-govdata-archiving/web-monitoring-ui/issues?q=is%3Aissue+is%3Aopen+label%3Afirst-timer) |
   | [**web-monitoring-db**](https://github.com/edgi-govdata-archiving/web-monitoring-db) | [`mozsprint`](https://github.com/edgi-govdata-archiving/web-monitoring-db/issues?q=is%3Aissue+is%3Aopen+label%3Amozsprint), [`first-timer`](https://github.com/edgi-govdata-archiving/web-monitoring-db/issues?q=is%3Aissue+is%3Aopen+label%3Afirst-timer) |

---

This repository is the database and API underlying the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of monitored pages and revisions that have been made to them
- Allows other services to add new tracked pages/versions (we are currently focused on Versionista, but this database will soon host data from other sources, such as the Internet Archive)
- Provides an API to get that version data and allow analysts or other automated tools to annotate those versions with metadata


## Installation

1. Ensure you have Ruby 2.4.1+
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

7. Set up your database. The simple way to do this is:

    ```sh
    $ bundle exec rake db:setup
    ```

    That will create a database, set up all the tables, create an admin user, and add some sample data. Make note of the admin user e-mail and password that are shown; you’ll need them to log in and create more users, import more data, or make annotations.

    If you’d like to do the setup manually, see [advanced setup](#advanced-setup) below.

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

## Advanced Setup

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


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/master/LICENSE) file for details.
