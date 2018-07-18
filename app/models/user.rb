
class User < ActiveRecord::Base
  has_many :pipelines
  validates_length_of :name, :within => 3..40
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :crypted_password

  attr :password

  include GuidHelper
  before_create :set_guid

  def set_password(clear_text_password)
    self.crypted_password = User.encrypt_password(clear_text_password)
  end

  # encapsulate biz logic in 1 place ...
  def User.encrypt_password(clear_text_password)
    crypted_password = Digest::MD5.hexdigest(clear_text_password)
    return crypted_password
  end

  def User.is_valid_login(user_name, clear_text_password)
    crypted_password = User.encrypt_password(clear_text_password)
    user = User.where(name: user_name, crypted_password: crypted_password).first
    return user
  end

end
