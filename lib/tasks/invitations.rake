desc 'Clean out expired invitations'
task :remove_expired_invitations, [] => [:environment] do |t, args|
  Invitation.expired.each do |invitation|
    invitation.destroy
  end
end
