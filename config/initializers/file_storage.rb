require_dependency 'file_storage/file_storage'
require_dependency 'file_storage/s3'

if ENV['AWS_WORKING_BUCKET']
  FileStorage.default = FileStorage::S3.new(
    bucket: ENV['AWS_WORKING_BUCKET'],
    region: ENV['AWS_WORKING_REGION'] || ENV['AWS_REGION'],
    acl: 'private'
  )
else
  storage_path = Rails.root.join('tmp/storage/working')
  FileStorage.default = FileStorage::LocalFile.new(path: storage_path)
end
