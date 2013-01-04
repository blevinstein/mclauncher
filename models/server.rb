require 'aws-sdk'

class Server
  include DataMapper::Resource

  @@image_id = 'ami-1624987f'
  def self.image_id
    @@image_id
  end

  belongs_to :user

  property :instance_id, String, :key => true

  def start
    self.instance_id = ec2.instances.create(:image_id => Server.image_id,
                                      :instance_type => 't1.micro').id
    #instance.associate_elastic_ip(ec2.elastic_ips.allocate)
  end

  def status
    ec2.instances[instance_id].status
  end

  def reboot
    instance.reboot
  end

  def stop
    #instance.disassociate_elastic_ip
    instance.terminate
  end

  def instance
    @instance = @instance || ec2.instances[instance_id]
  end
  
  def ec2
    @ec2 = @ec2 || AWS::EC2.new(:access_key_id => user.access_key_id,
                                :secret_access_key => user.secret_access_key)
  end
end
