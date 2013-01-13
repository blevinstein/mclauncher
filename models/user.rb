require 'digest/sha1'

class User
  include DataMapper::Resource

  has n, :servers
  has n, :backups

  property :username,          String,  :key => true
  property :password_hash,     String,  :required => true
  property :password_salt,     String,  :required => true
  property :access_key_id,     String
  property :secret_access_key, String
  property :private_key,       String,  :length => 2048
  
  def self.config
    @@config ||= YAML.load(open('./config.yml').read)
  end

  def password=(new_password)
    self.password_salt = Time.now.to_f.to_s + username
    self.password_hash = Digest::SHA1.hexdigest(new_password + password_salt)
  end

  def password?(given_password)
    Digest::SHA1.hexdigest(given_password + password_salt) == password_hash
  end

  def set_aws_keys(access_key, secret_key)
    # update ec2 and s3 credentials
    fail unless update(:access_key_id => access_key,
                       :secret_access_key => secret_key)
    @ec2 = nil
    @s3 = nil
    # generate key pair
    key_pair = ec2.key_pairs[User.config['key_pair']]
    key_pair.delete if key_pair.exists?
    #fail unless update(:private_key => ec2.key_pairs.create(User.config['key_pair']).private_key)
    update(:private_key => ec2.key_pairs.create(User.config['key_pair']).private_key)
    # create security group
    if not ec2.security_groups.any? {|group| group.name == User.config['security_group']}
      security_group = ec2.security_groups.create(User.config['security_group'])
      security_group.authorize_ingress(:tcp, 22) # ssh
      security_group.authorize_ingress(:tcp, 25565) # minecraft
      security_group.allow_ping
    end
    # create a backups bucket on S3
    s3.buckets.create(User.config['s3_bucket']) unless s3.buckets[User.config['s3_bucket']].exists?
  end

  def ec2
    @ec2 ||= AWS::EC2.new(:access_key_id => access_key_id,
                          :secret_access_key => secret_access_key)
  end
  
  def s3
    @s3 ||= AWS::S3.new(:access_key_id => access_key_id,
                        :secret_access_key => secret_access_key)
  end
end
