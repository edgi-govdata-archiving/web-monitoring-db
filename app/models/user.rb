class User < ApplicationRecord
  PERMISSIONS = [
    VIEW_PERMISSION = 'view'.freeze,
    ANNOTATE_PERMISSION = 'annotate'.freeze,
    IMPORT_PERMISSION = 'import'.freeze,
    MANAGE_USERS_PERMISSION = 'manage_users'.freeze
  ].freeze

  PERMISSION_DESCRIPTIONS = {
    VIEW_PERMISSION => 'See versions and pages',
    ANNOTATE_PERMISSION => 'View and create annotations',
    IMPORT_PERMISSION => 'Import or create versions and pages',
    MANAGE_USERS_PERMISSION => 'Invite, and delete users and manage their permissions'
  }.freeze

  # Built-in Devise user modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :confirmable, :registerable

  # Note this relationship should be pretty ephemeral. Once a user confirms
  # their account, the associated invitation should be destroyed. (We keep
  # it around so that someone can re-use the invitation if they made a typo.)
  has_one :invitation, class_name: 'Invitation', foreign_key: 'redeemer_id', inverse_of: :redeemer

  validates :permissions, contains_only: PERMISSIONS
  attribute :permissions, :string, array: true, default: [VIEW_PERMISSION, ANNOTATE_PERMISSION]

  # We need to enforce some additional constraints on the invitation
  # relationship. This isn't great, but the best way I can see for now.
  def invitation=(invitation)
    if invitation
      invitation.destroy_unconfirmed_redeemer!
    end
    super
  end

  def permission?(permission)
    permissions.include? permission
  end

  PERMISSIONS.each do |permission|
    define_method :"can_#{permission}?" do
      permission?(permission)
    end
  end

  protected

  def after_confirmation
    if self.invitation
      self.invitation.destroy
      self.invitation = nil
    end
  end
end
