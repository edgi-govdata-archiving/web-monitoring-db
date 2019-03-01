require_dependency 'archiver/archiver'
require_dependency 'file_storage/file_storage'
require_dependency 'file_storage/s3'

if ENV['AWS_ARCHIVE_BUCKET']
  aws_key = ENV['AWS_ARCHIVE_KEY'] || ENV['AWS_ACCESS_KEY_ID']
  aws_secret = ENV['AWS_ARCHIVE_SECRET'] || ENV['AWS_SECRET_ACCESS_KEY']
  aws_region = ENV['AWS_ARCHIVE_REGION'] || ENV['AWS_REGION']
  aws_bucket = ENV['AWS_ARCHIVE_BUCKET']

  raise StandardError, 'You must specify either an "AWS_ARCHIVE_KEY" and ' \
    '"AWS_ARCHIVE_SECRET" or "AWS_ACCESS_KEY_ID" and "AWS_SECRET_ACCESS_KEY" ' \
    'to go use an S3 bucket for archiving versions.' if !(aws_key && aws_secret)

  Archiver.store = FileStorage::S3.new(
    key: aws_key,
    secret: aws_secret,
    region: aws_region,
    bucket: aws_bucket
  )
elsif !Rails.env.production?
  storage_path = Rails.root.join 'tmp/storage/archive'
  Archiver.store = FileStorage::LocalFile.new(path: storage_path)
end

Archiver.allowed_hosts = ENV['ALLOWED_ARCHIVE_HOSTS']
