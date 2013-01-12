require 'aws-sdk'
require 'uri/open-scp'

class Backup
  include DataMapper::Resource

  belongs_to :user, :key => true

  property :s3_key, String, :key => true
  
  def self.config
    @@config ||= YAML.load(open('./config.yml').read)
  end
  
  def self.create(server)
    timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
    filename = "world-#{timestamp}.tgz"
    Net::SSH.start(server.ip_address, config['user'], :key_data => [user.private_key]) do |ssh|
      ssh.exec! "tar cf #{filename} world"
    end
    tmp = Tempfile.new('backup')
    tmp.close
    Net::SCP.download!(server.ip_address, config['user'], filename, tmp.path, :key_data => [user.private_key])
    obj = user.s3.buckets[config['s3_bucket']].objects.create(timestamp)
    obj.write(File.open(tmp.path, 'r'))
    f.unlink
    Backup.new(:user => server.user, :s3_key => timestamp)
  end

  def restore(server)
    tmp = Tempfile.new('restore')
    tmp.close
    filename = "world-#{s3_key}.tgz"
    obj = user.s3.buckets[config['s3_bucket']].objects[s3_key]
    File.open(tmp.path, 'w') do |f|
      obj.read do |chunk|
        f.write(chunk)
      end
    end
    Net::SCP.upload!(server.ip_address, config['user'], tmp.path, filename, :key_data => [user.private_key])
    Net::SSH.start(server.ip_address, config['user'], :key_data => [user.private_key]) do |ssh|
      ssh.exec! "rm -rf world"
      ssh.exec! "tar xf #{filename} world"
    end
  end
end
