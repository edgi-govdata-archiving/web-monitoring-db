require_dependency Rails.root.join('lib/archiver/archiver')
require_dependency Rails.root.join('lib/archiver/stores/s3')

Archiver.store = Archiver::Stores::S3.new(
  key: ENV['AWS_S3_KEY'],
  secret: ENV['AWS_S3_SECRET'],
  region: ENV['AWS_S3_REGION'],
  bucket: ENV['AWS_S3_BUCKET']
)
Archiver.allowed_hosts = ENV['ALLOWED_ARCHIVE_HOSTS']
