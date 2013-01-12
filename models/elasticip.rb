require 'aws-sdk'

class ElasticIp
  include DataMapper::Resource

  belongs_to :user
  belongs_to :server

  property :ip_address, String, :key => true

  def self.create(user)
    ip = user.ec2.elastic_ips.allocate
    super(:user => user, :ip_address => ip)
  end

  def associate(instance)
    fail if server.nil?
    elastic_ip.associate(:instance => server.instance_id)
  end

  def associated?
    elastic_ip.associated?
  end

  def disassociate
    elastic_ip.disassociate
  end

  def destroy
    elastic_ip.release
    super
  end

  def elastic_ip
    @elastic_ip = @elastic_ip || user.ec2.elastic_ips[ip_address]
  end
end
