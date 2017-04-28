require_dependency Rails.root.join('lib/archiver/archiver')
require_dependency Rails.root.join('lib/archiver/stores/s3')

if ENV['AWS_S3_KEY'] && ENV['AWS_S3_SECRET'] && ENV['AWS_S3_BUCKET']
  Archiver.store = Archiver::Stores::S3.new(
    key: ENV['AWS_S3_KEY'],
    secret: ENV['AWS_S3_SECRET'],
    region: ENV['AWS_S3_REGION'],
    bucket: ENV['AWS_S3_BUCKET']
  )
end

if ENV['ALLOWED_ARCHIVE_HOSTS']
  Archiver.allowed_hosts = ENV['ALLOWED_ARCHIVE_HOSTS']
end
