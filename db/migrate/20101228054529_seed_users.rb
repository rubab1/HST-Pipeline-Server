class SeedUsers < ActiveRecord::Migration[5.1]
  def self.up
    # drop all old users - 
    ActiveRecord::Base.connection.execute("TRUNCATE users") 

    uuu = User.create
    uuu.name = 'dummy'
    uuu.email = 'dummy@gmail.com'
    uuu.is_admin = true
    uuu.set_password('myDumyPwd')
    uuu.save!

  end

  def self.down
    # no real rolling back from this ...
    raise new ActiveRecord::IrreversibleMigration
  end
end
