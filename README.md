[![Code of Conduct](https://img.shields.io/badge/%E2%9D%A4-code%20of%20conduct-blue.svg?style=flat)](https://github.com/edgi-govdata-archiving/overview/blob/main/CONDUCT.md) &nbsp;[![Project Status Board](https://img.shields.io/badge/✔-Project%20Status%20Board-green.svg?style=flat)](https://github.com/orgs/edgi-govdata-archiving/projects/4)

# web-monitoring-db

This repository is the database and API underlying the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring). It’s a Rails app that:

- Acts as a database of monitored pages and captured versions of those pages over time.

    *(The application does not record new versions itself, but relies on importing data from external services, like [the Internet Archive](https://archive.org) or [Versionista](https://versionista.com). See [“How Data Gets Loaded”](#how-data-gets-loaded) below for more.)*

- Provides an API to get that page and version data, and to allow analysts or other automated tools to annotate those versions with metadata about what has changed from version to version.

For more about how data is modeled in this project, see [“Data Model”](#data-model) below.

API documentation is available from the homepage of the application, e.g. by pointing your browser to http://localhost:3000/ or https://api.monitoring.envirodatagov.org. It’s generated from our OpenAPI docs in [`swagger.yml`](./swagger.yml).

We maintain a publicly available *staging server* at https://api-staging.monitoring.envirodatagov.org that you can test against. It runs the latest code and has non-production data — it’s safe to modify or post new versions or annotations to, but you should not rely on that data sticking around; it may get reset at any time. **For access, ask for an account on Slack or use the public user credentials:**

- Username: `public.access@envirodatagov.org`
- Password: `PUBLIC_ACCESS`


## Installation

1. Ensure you have Ruby 2.6.6+.

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

    - If you’d like to configure your Postgres DB to use a specific user, you’ll need to do a little more work:

        1. Log into `psql` and create a new user for your databases. Change the username and password to whatever you’d like:

            ```sql
            CREATE USER wm_dev_user WITH SUPERUSER PASSWORD 'wm_dev_password';
            ```
            Unfortunately,
           [Rails' test fixtures require nothing less than superuser privileges in PostgreSQL](https://edgeguides.rubyonrails.org/testing.html#fixtures-in-action).

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

11. Bulk importing, automated analysis, and e-mail invitations all run as asynchronous jobs, managed by a Redis queue. If you plan to use any of these features, you must also start a Redis server and worker.

    Start redis:

    ```sh
    $ redis-server
    ```

    Start a worker:

    ```sh
    $ QUEUE=* VERBOSE=1 bundle exec rake environment resque:work
    ```

    If you only want to run particular type of job, you can set a list of queue names in the `QUEUES` environment variable:

    ```sh
    $ QUEUES=mailers,import,analysis VERBOSE=1 bundle exec rake environment resque:work
    ```

    Each job type runs on a different queue:

    - `mailers`: Sending e-mails. (There's no job associated with this queue because it is automatically processed by ActionMailer, a built-in component of Rails.)
    - `import`: Bulk version imports (processing data sent to the `/api/v0/imports` endpoint).
    - `analysis`: Auto-analyze changes between versions and create annotations with the results.


### Manual Postgres Setup

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


### Docker

The Dockerfile runs the rails server on port 3000 in the container. To build
and run:

```
docker build --target rails-server -t envirodgi/db-rails-server .
docker build --target import-worker -t envirodgi/db-import-worker .
docker run -p 3000:3000 envirodgi/db-rails-server -e <ENVIRONMENT VARIABLES> .
docker run -p 6379:6379 envirodgi/db-import-worker -e <ENVIRONMENT VARIABLES> .
```

Point your browser or ``curl`` at ``http://localhost:3000``.


## Data Model

The database models three main types of data:

- **Pages**, which represent a page on the internet. Pages are identified by a unique ID rather than their URL because pages can move or be available from multiple URLs. *(Note: we don't actually model that yet, though! See [#492](https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/492) for more.)*

- **Versions**, which represent a particular page at a particular point in time. We use the term “version” instead of others more common in the archival space because we attempt to only represent *different* versions. That is, if a page changed on Wednesday and we captured copies of it on Monday, Tuesday, and Wednesday, we only make version records for Monday and Wednesday (because Tuesday was the same as Monday).

    *(Note: because of technical issues around imported data, we often store more versions than we should according to the above definition [e.g. we might still have a record for Tuesday]. Versions have a `different` field that indicates whether a version is different from the previous one, and the API only returns versions that are `different` unless you explicitly request otherwise.)*

- **Annotations**, which represent an analysis about what’s changed between any two *versions* of a *page*. Annotations have a specialized `priority` and `significance`, which are numbers between 0 and 1, an `author`, indicating who made the analysis (it could be a bot account), and an `annotation` field, which is a JSON object with no specified structure (inside this field, annotations can include any data desired).

There are several other kinds of objects, but they are subservient to the ones above:

- **Changes**, which serve to connect any two *versions* of a *page*. *Annotations* are actually connected to *changes*, rather than directly to two *versions*. You can also generate diffs for a given *change*.

- **Tags**, which can be applied to pages. They help sort and categorize things. Most tags are manually applied, but the application auto-generates a few:
    - `domain:<domain name>`, e.g. `domain:www.epa.gov` for a page at `https://www.epa.gov/citizen-science`
    - `2l-domain:<second-level domain name>` e.g. `2l-domain:epa.gov` for a page at `https://www.epa.gov/citizen-science`

- **Maintainers**, which can be applied to pages. They represent organizations that maintain a given page. For example, the page at `https://www.epa.gov/citizen-science` is maintained by `EPA`.

- **Imports** model requests to import new data and the results of the import operation.

- **Users** model people (both human and bots) who can view, import, and annotate data. You currently have to have a user account to do anything in the application, though we hope accounts will not be needed to view public data in the future.

Actual database schemas for each of these tables is listed in [`db/schema.rb`](./db/schema.rb).


### How Data Gets Loaded

The web-monitoring-db project does not actually monitor or scrape pages on the web. Instead, we rely on importing data from other services, like [the Internet Archive](https://archive.org). Each day, a script queries other services for historical snapshots and sends the results to the `/api/v0/imports` endpoint.

Most of the data sent to `/api/v0/imports` matches up directly with the structure of the [`Version` model](./db/schema.rb). However, the `body_url` field in an import is treated specially.

When new page or version data is imported, the `body_url` field points to a location where the raw HTTP response body can be retrieved. If the `body_url` host matches one of the values in the [`ALLOWED_ARCHIVE_HOSTS` environment variable](./.env.example), the version record that gets added to the database will simply point to that external location as a source of raw response data. Otherwise, the application downloads the data from `body_url` and stores it in its `FileStorage`.

The intent is to make sure data winds up at a reliably available location, ensuring that anyone who can access the API can also access the raw response body for any version. Hosts should be listed in `ALLOWED_ARCHIVE_HOSTS` if they meet this criteria better than the application’s own file storage. The application’s storage area can be the local disk or it can be S3, depending on configuration. The component can take pluggable configurations, so we can support other storage types or locations in the future.

You can see more about this process in:
- The overview repo’s [“architecture” document](https://github.com/edgi-govdata-archiving/web-monitoring/blob/main/ARCHITECTURE.md#web-page-snapshottingcapturing-workflow)
- The [import job code](./app/jobs/import_versions_job.rb), where imports are processed.
- The [`Archiver` module code](./lib/archiver/archiver.rb), where raw HTTP response data is saved.


### File Storage

The application needs to store files for several different purposes (storing raw import data, archiving HTTP response bodies as described in the previous section, specialized logs, etc). To do this, it uses the [`FileStorage`](https://github.com/edgi-govdata-archiving/web-monitoring-db/tree/main/lib/file_storage) module, which has different implementations for different types of storage, such as [the local disk](https://github.com/edgi-govdata-archiving/web-monitoring-db/blob/main/lib/file_storage/local_file.rb) or [Amazon S3](https://github.com/edgi-govdata-archiving/web-monitoring-db/blob/main/lib/file_storage/s3.rb).

At current, the application creates two `FileStorage` instances:

1. “Archival storage” is used to store raw HTTP response bodies for each version of a page. See the [“how data gets loaded” section](#how-data-gets-loaded) for more details. Under a default configuration, this is your local disk in development and S3 in production. You can configure the S3 bucket used for it with the `AWS_ARCHIVE_BUCKET` environment variable. **Everything in this storage area is publicly available.**

2. “Working storage” is used to store internal data, such as raw import data and import logs. Under a default configuration, this is your local disk in development and S3 in production. You can configure the S3 bucket used for it with the `AWS_WORKING_BUCKET` environment variable. **Everything in this storage area should be considered private and you should not expose it to the public web.**

3. For historical reasons, EDGI’s deployment includes a third S3 bucket that is not directly accessed by the application. It’s where we store HTTP response bodies collected from [Versionista](https://versionista.com), a service we previously used for scraping government web pages. You can see it listed in [the example settings for `ALLOWED_ARCHIVE_HOSTS`](https://github.com/edgi-govdata-archiving/web-monitoring-db/blob/main/.env.example).


## Releases

New releases of the app are published automatically as Docker images by CircleCI when someone pushes to the `release` branch. They are availble at https://hub.docker.com/r/envirodgi. See [web-monitoring-ops](https://github.com/edgi-govdata-archiving/web-monitoring-ops) for how we deploy releases to actual web servers.

Images are tagged with the SHA-1 of the git commit they were built from. For example, the image `envirodgi/db-rails-server:ddc246819a039465e7711a1abd61f67c14b7a320` was built from [commit `ddc246819a039465e7711a1abd61f67c14b7a320`](https://github.com/edgi-govdata-archiving/web-monitoring-db/commit/ddc246819a039465e7711a1abd61f67c14b7a320).

We usually create *merge commits* on the `release` branch that note the PRs included in the release or any other relevant notes (e.g. [`Release #503, #504`](https://github.com/edgi-govdata-archiving/web-monitoring-db/commit/67e4510d1f2a8c7f01542cc86a6361539ef77fa5)).


## Code of Conduct

This repository falls under EDGI's [Code of Conduct](https://github.com/edgi-govdata-archiving/overview/blob/main/CONDUCT.md).


## Contributors

This project wouldn’t exist without a lot of amazing people’s help. Thanks to the following for all their contributions! See our [contributing guidelines](https://github.com/edgi-govdata-archiving/web-monitoring-db/blob/main/CONTRIBUTING.md) to find out how you can help.

<!-- ALL-CONTRIBUTORS-LIST:START -->
| Contributions | Name |
| ----: | :---- |
| [📖](# "Documentation") [👀](# "Reviewer") | [Dan Allan](https://github.com/danielballan) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Andrew Bergman](https://github.com/ambergman) |
| [💻](# "Code") [🚇](# "Infrastructure") [📖](# "Documentation") [💬](# "Answering Questions") [👀](# "Reviewer") | [Rob Brackett](https://github.com/Mr0grog) |
| [💻](# "Code") | [Alessandro Caporrini](https://github.com/acaporrini) |
| [📖](# "Documentation") | [Patrick Connolly](https://github.com/patcon) |
| [💻](# "Code") | [Robert Dalin](https://github.com/rdalin82) |
| [💻](# "Code") | [Kate Donaldson](https://github.com/katelovescode) |
| [📖](# "Documentation") | [Michael Hardy](https://github.com/michardy) |
| [💻](# "Code") | [Kasper Holbek Jensen](https://github.com/kholbekj) |
| [💻](# "Code") | [Shishir Joshi](https://github.com/shishir127) |
| [💻](# "Code") [📖](# "Documentation") | [Krzysztof Madejski](https://github.com/KrzysztofMadejski) |
| [📖](# "Documentation") | [Ansar Memon (Amoury)](https://github.com/amoury) |
| [📖](# "Documentation") [📋](# "Organizer") [📢](# "Talks") | [Matt Price](https://github.com/titaniumbones) |
| [📋](# "Organizer") [🔍](# "Funding/Grant Finder") | [Toly Rinberg](https://github.com/trinberg) |
| [💻](# "Code") | [Ben Sheldon](https://github.com/bensheldon) |
| [💻](# "Code") | [Ewelina Sobora](https://github.com/ewelinasobora) |
| [🚇](# "Infrastructure")  | [Frederik Spang](https://github.com/frederikspang) |
| [💻](# "Code") | [Max Tedford](https://github.com/maxtedford) |
| [💻](# "Code") | [Eddie Tejeda](https://github.com/eddietejeda) |
| [📖](# "Documentation") [📋](# "Organizer") | [Dawn Walker](https://github.com/dcwalk) |
<!-- ALL-CONTRIBUTORS-LIST:END -->

(For a key to the contribution emoji or more info on this format, check out [“All Contributors.”](https://github.com/kentcdodds/all-contributors))


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/main/LICENSE) file for details.
