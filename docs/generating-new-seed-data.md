# Generating New Seed Data

From time to time, it might make sense to create updated seed data for new developers. In general, it’s easiest to simply pull a subset of pages and versions from the production API — but be careful not to include versions less than a month old (because of concerns discussed elsewhere about alarmism, people reading too much into the data, etc. — see issues and meeting transcripts for more on that).

The following is a simple Python script for loading a sampling of pages and formatting their versions as imports. It uses the tools available in [web-monitoring-processing](https://github.com/edgi-govdata-archiving/web-monitoring-processing).

```py
# This script generates new seed data for web-monitoring-db. It loads a random
# sampling of pages and their versions from the production API and formats them
# as new imports for another instance of web-monitoring-db.

import json
from datetime import datetime
from dateutil.parser import parse as parse_timestamp
from web_monitoring import db

# Don't include versions newer than this
MAX_DATE = parse_timestamp('2018-06-29T00:00:00Z')
# Number of pages to include
SAMPLE_SIZE = int(150 * 4 / 3)  # ~25% will have only one version, but we want ~150
# Number of pages with only one version to accept
MAX_SINGLE_VERSION_PAGES = 2


# Get a random sampling of pages to include in the seed data
print(f'Sampling {SAMPLE_SIZE} pages')
client = db.Client.from_env()
sampled_pages = []
for number in random.sample(range(url_count), SAMPLE_SIZE):
    page = client.list_pages(chunk=number, chunk_size=1)['data'][0]
    sampled_pages.append(page)
    print('  Got ID #{}: {}'.format(len(sampled_pages), page['uuid']))


# Load the versions for each page and format them as import records
print(f'Loading versions for sampled pages')
records = []
single_version_pages = 0
for index, page in enumerate(sampled_pages):
    versions = client.list_versions(page_id=page['uuid'])['data']
    versions = [version for version in versions if version['capture_time'] <= MAX_DATE]
    version_count = len(versions)
    if version_count <= 1:
        if single_version_pages > MAX_SINGLE_VERSION_PAGES:
            print(f'  Dropping page #{index} (Only {version_count} version)')
            continue
        else:
            single_version_pages += 1

    for version in versions:
        records.append({
            "capture_time": version['capture_time'].isoformat().replace('+00:00', 'Z'),
            "uri": version['uri'],
            "version_hash": version['version_hash'],
            "source_type": version['source_type'],
            "source_metadata": version['source_metadata'],
            "page_url": version['capture_url'],
            "page_title": version['title'],
            "page_maintainers": [maintainer['name'] for maintainer in page['maintainers']],
            "page_tags": [tag['name'] for tag in page['tags']],
            "uuid": version['uuid']
        })
    print(f'  Collected versions for page #{index} ({version_count} versions)')


# Write records as an ND-JSON file
print('Writing new seed data to `seed_import.json`')
with open('./seed_import.json', 'w') as file:
    for record in records:
        file.write(json.dumps(record))
        file.write('\n')

print('Done!')
```
