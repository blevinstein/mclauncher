require 'digest/sha1'

class User
  include DataMapper::Resource

  has n, :servers

  property :username,          String, :key => true
  property :password_hash,     String, :required => true
  property :password_salt,     String, :required => true
  property :access_key_id,     String
  property :secret_access_key, String

  def password=(new_password)
    self.password_salt = Time.now.to_s + username
    self.password_hash = Digest::SHA1.hexdigest(new_password + password_salt)
    save
  end

  def password?(given_password)
    Digest::SHA1.hexdigest(given_password + password_salt) == password_hash
  end
end
