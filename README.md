# web-monitoring-db

**Still just a proof-of-concept at the moment!**

This is essentially a more automated version of the page monitoring workflow currently managed through a combination of [versionista-outputter](https://github.com/edgi-govdata-archiving/versionista-outputter/), Google spreadsheets, and *lots* of manual work. This repository is part of the EDGI [Web Monitoring Project](https://github.com/edgi-govdata-archiving/web-monitoring).

It’s a Rails app that:

- Acts as a database of tracked pages and revisions that have been made to them
- Can automatically update itself from Versionista
- [Not yet done] Provides an API to get revision data and allow analysts to update metadata about the revision


## Installation

1. Ensure you have Ruby 2.4.0+
2. You don’t have the `bundler` Ruby gem, install it:

  ```sh
  $ gem install bundler
  ```

3. Clone this repo
4. Wherever you cloned the repo, go to that directory and:

   ```sh
   $ bundle install
   $ rails server
   ```

5. You should now have a server running and can visit it at http://localhost:3000/

To actually pull down new revisions in the last 24 hours from Versionista:

```sh
$ VERSIONISTA_EMAIL=login-email-here VERSIONISTA_PASSWORD=login-password-here rake update_from_versionista[24]
```

Just be sure to replace `login-email-here` and `login-password-here` with the appropriate values :)

The `[24]` at the end is how many hours before now to start. You can add a second argument to tell it not to include revisions newer than so many hours ago. For example, to only retrieve revisions created between 24 and 12 hours ago:

```sh
$ rake update_from_versionista[24,12]
```

If you just want to scrape the info from Versionista and store it in a JSON file for later use without updating the DB:

```
$ VERSIONISTA_EMAIL=login-email-here VERSIONISTA_PASSWORD=login-password-here rake scrape_from_versionista[24]
```

This will create a JSON file named `scraped_data-[from hours]-[until hours].json` (e.g. `scraped_data-24-0.json` in the example above) and put it in the `tmp` directory. You can specify a different file path to use as a third argument in square brackets.

And to update the DB from that scraped data:

```
$ rake update_from_json['./tmp/scraped_data-24-0.json']
```

The argument in square brackets should be the path to your JSON file.


## License & Copyright

Copyright (C) 2017 Environmental Data and Governance Initiative (EDGI)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3.0.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the [`LICENSE`](https://github.com/edgi-govdata-archiving/webpage-versions-db/blob/master/LICENSE) file for details.
