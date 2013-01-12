require 'aws-sdk'
require 'yaml'

class Server
  include DataMapper::Resource

  belongs_to :user
  has 1, :elastic_ip

  property :instance_id, String, :key => true
  property :private_key, String

  def self.config
    @@config ||= YAML.load(open('./config.yml').read)
  end

  def self.create(user)
    id = user.ec2.instances.create(:image_id => config['image_id'],
                                   :instance_type => 't1.micro',
                                   :key_name => User.config['key_pair'],
                                   :security_groups => User.config['security_group']).id
    super(:user => user, :instance_id => id, :private_key => user.private_key)
  end

  def status
    instance.status
  end

  def reboot
    instance.reboot
  end

  def stop
    instance.stop
  end

  def destroy
    instance.terminate
    super
  end

  def instance
    @instance ||= user.ec2.instances[instance_id]
  end
end
