class AddDeviseSecurityFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |t|
      # Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      # Lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      # Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
    end

    add_index :users, :confirmation_token, unique: true
    add_index :users, :unlock_token,       unique: true
  end
end
