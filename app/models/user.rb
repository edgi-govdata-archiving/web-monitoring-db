class User < ApplicationRecord
  # Built-in Devise user modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :confirmable
end
