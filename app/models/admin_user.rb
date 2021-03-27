class AdminUser < ApplicationRecord
  devise :database_authenticatable, :lockable,
         :recoverable, :rememberable, :validatable
end
