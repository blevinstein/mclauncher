require 'aws'
require 'data_mapper'

$environment = :development

DataMapper::Model.raise_on_save_failure = true
DataMapper.setup :default, ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/db"
Dir['./models/*'].each { |model| require model }
DataMapper.finalize
DataMapper.auto_upgrade! if $environment == :development
