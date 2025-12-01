# frozen_string_literal: true

class Invitation < ApplicationRecord
  EXPIRATION_DAYS = 14

  # Invitations are attached to a user when the user is created using an invitation
  belongs_to :issuer, class_name: 'User', optional: true
  belongs_to :redeemer, class_name: 'User', optional: true, inverse_of: :invitation

  before_create :assign_code, :ensure_expiration
  validate :not_for_existing_user, on: :create
  validates :email, format: { with: /\A[^@\s]+@([^@.\s]+\.)+[^@.\s]+\z/ }, allow_blank: true

  def self.expired
    self.where('expires_on < ?', Time.now)
  end

  def expired?
    self.expires_on.present? && Time.now < self.expires_on
  end

  def send_email
    InvitationMailer.invitation_email(self).deliver_later if self.email.present?
  end

  # Overriding this is not the best way to enforce extra constraints (see
  # destroy_unconfirmed_redeemers! below), but best I can figure for now.
  def redeemer=(new_redeemer)
    destroy_unconfirmed_redeemer!
    super
  end

  # Before assigning a new redeemer, we want to destroy any accounts
  # that were created with this invitation but not confirmed -- this lets
  # someone reuse an invitation if they entered the wrong e-mail address.
  #
  # Additionally, we want to prevent assignment to a new redeemer if the
  # current one has already been confirmed (this *should* never happen
  # because confirming a user destroys its invitation, but it's still
  # possible to wind up in this situation).
  def destroy_unconfirmed_redeemer!
    if self.redeemer
      if self.redeemer.active_for_authentication?
        raise 'This invitation has already been redeemed and confirmed'
      else
        old_redeemer = self.redeemer
        update_column(:redeemer_id, nil)
        old_redeemer.destroy
      end
    end
  end

  private

  def assign_code
    self.code = loop do
      token = generate_code
      break token unless Invitation.where(:code => token).exists?
    end
  end

  def generate_code
    SecureRandom.hex(10).to_s
  end

  def ensure_expiration
    unless self.expires_on
      self.expires_on = Time.now + EXPIRATION_DAYS.days
    end
  end

  def not_for_existing_user
    if self.email.present? && User.find_by_email(self.email)
      errors.add(:email, 'is already a user')
    end
  end
end
