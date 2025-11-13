# frozen_string_literal: true

desc 'Clean out expired invitations'
task :remove_expired_invitations, [] => [:environment] do
  Invitation.expired.each do |invitation|
    invitation.destroy
  end
end
