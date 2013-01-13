require 'aws-sdk'
require 'yaml'

require 'rufus/scheduler'

class Server
  include DataMapper::Resource

  belongs_to :user
  has 1, :elastic_ip

  property :instance_id, String, :key => true
  property :private_key, String, :length => 2048

  def self.config
    @@config ||= YAML.load(open('./config.yml').read)
  end

  def self.create(user)
    id = user.ec2.instances.create(:image_id => config['image_id'],
                                   :instance_type => 't1.micro',
                                   :key_name => User.config['key_pair'],
                                   :security_groups => User.config['security_group']).id
    server = super(:user => user, :instance_id => id, :private_key => user.private_key)
    server.schedule(:jar_download)
  end

  %w(status stop terminate reboot ip_address).each do |meth|
    define_method(meth) do
      instance.send(meth)
    end
  end

  def start
    instance.start
    schedule(:jar_download)
  end

  def with_ssh(server)
    lambda do |job|
      if status == :running
        begin
          yield Net::SSH.start(ip_address, Server.config['user'], :key_data => private_key)
          #log 'Would unschedule now.'
          job.unschedule
        rescue Errno::ECONNREFUSED
          log 'Connection refused.'
        rescue Net::SSH::ConnectionTimeout
          log 'Timeout.'
        rescue Exception => e
          log "Exception: #{e}"
        end
      else
        log 'Not running.'
      end
    end
  end

  def log(msg)
    puts "[#{instance_id}] #{msg}"
  end

  def schedule(action)
    case action
    when :jar_download
      # download minecraft_server.jar from minecraft.net
      scheduler.every '5s', (with_ssh(self) do |ssh|
        log 'Downloading...'
        ssh.exec! "wget http://minecraft.net/download/minecraft_server.jar"
        log 'Downloaded!'
        schedule(:start_minecraft)
      end)
    when :start_minecraft
      # start minecraft_server.jar
      scheduler.every '5s', (with_ssh(self) do |ssh|
        log 'Starting...'
        ssh.exec! "nohup java -Xmx512M -Xms512M -jar minecraft_server.jar &"
        log 'Started!'
      end)
    end
  end

  def destroy
    terminate if status != :terminated
    super
  end

  def instance
    @instance ||= user.ec2.instances[instance_id]
  end

  def scheduler
    @scheduler ||= Rufus::Scheduler.start_new
  end
end
