class AdminUser < ApplicationRecord
  devise :database_authenticatable, :lockable,
         :recoverable, :rememberable, :validatable

  def self.ransackable_attributes(auth_object = nil)
    %w[email current_sign_in_at sign_in_count created_at]
  end
end
