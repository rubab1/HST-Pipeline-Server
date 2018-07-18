class CreateDataProducts < ActiveRecord::Migration[5.1]

  #  Some special tag names always exist and have special fields in the
  #  database.  These special tags include
  #     'Datatype'             = data_type = {"Image", "Table", "Datafile", "Other"}
  #     'ImageType'            = subtype   = {"science", "drizzle" }
  #     'Configuration group'  = group     = {"prod", "raw", "log" ... }

  def self.up
    create_table :data_products do |t|
      t.string :relativepath
      t.string :filename
      t.references :configuration
      t.bigint :hashvalue
      t.string :s3bucket
      t.string :s3objectid
      t.string :s3region
      t.bigint :lockserial
      t.references :user
      t.string :locktype
      t.timestamp :lockgranted
      t.datetime :lockexpire
      t.string :s3state
      t.string :data_type
      t.string :subtype
      t.string :suffix
      t.string :data_source
      t.string :group
      t.integer :binfiltercommon
      t.integer :binfiltermiddle
      t.integer :binfilternarrow
      t.float :ra
      t.float :dec
      t.float :pointing_angle
      t.timestamps
    end
  end

  def self.down
    drop_table :data_products
  end
end
