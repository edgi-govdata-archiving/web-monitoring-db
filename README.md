# web-monitoring-db

This is essentially a more automated version of the page monitoring workflow currently managed through a combination of [versionista-outputter](https://github.com/edgi-govdata-archiving/versionista-outputter/), Google spreadsheets, and *lots* of manual work. This repository is part of the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of tracked pages and revisions that have been made to them
- Allows other services (not just Versionista) to add new tracked pages/versions
- Provides an API to get version data and allow analysts to update metadata about the revision


## Installation

1. Ensure you have Ruby 2.4.0+
2. Ensure you have PostgreSQL 9.5+
3. Ensure you have Redis
4. If you don’t have the `bundler` Ruby gem, install it:

  ```sh
  $ gem install bundler
  ```

3. Clone this repo
4. Wherever you cloned the repo, go to that directory and:

   ```sh
   $ bundle install
   $ bundle exec rake db:setup
   $ bundle exec rails server
   ```

5. You should now have a server running and can visit it at http://localhost:3000/. It will be populated with a few pages and versions a simple admin user (`seed-admin@example.com`), whose password will have been shown when you ran `rake db:setup`. Log in with that user account to create new users.


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/master/LICENSE) file for details.
