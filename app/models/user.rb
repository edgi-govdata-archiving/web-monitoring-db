class User < ApplicationRecord
  # Built-in Devise user modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :confirmable, :registerable

  # Note this relationship should be pretty ephemeral. Once a user confirms
  # their account, the associated invitation should be destroyed. (We keep
  # it around so that someone can re-use the invitation if they made a typo.)
  has_one :invitation, class_name: 'Invitation', foreign_key: 'redeemer_id', inverse_of: :redeemer

  # We need to enforce some additional constraints on the invitation
  # relationship. This isn't great, but the best way I can see for now.
  def invitation=(invitation)
    if invitation
      invitation.destroy_unconfirmed_redeemer!
    end
    super(invitation)
  end

  protected

  def after_confirmation
    if self.invitation
      self.invitation.destroy
      self.invitation = nil
    end
  end
end
