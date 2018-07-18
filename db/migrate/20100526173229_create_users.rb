class CreateUsers < ActiveRecord::Migration[5.1]
  def self.up
    create_table :users do |t|
      t.string :name
      t.string :guid
      t.string :crypted_password
      t.string :email
      t.boolean :is_admin, :default => 0

      t.timestamps
    end
    add_index :users, :guid, { :name => "users_guid_index", :unique => true }
  end

  def self.down
    drop_table :users
  end
end
