require 'application_system_test_case'

class UsersTest < ApplicationSystemTestCase
  test 'Invite, register, confirm, promote, demote, delete' do
    admin = users(:admin_user)
    viewer_email = 'user@example.com'

    #
    # Administrator sends a user invitation
    #
    Capybara.using_session(:admin) do
      visit root_path

      click_on 'Login'

      fill_in 'Email', with: admin.email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content?("Logged in as #{admin.email}"), 'Admin should have an active session'
      click_on 'Admin'

      perform_enqueued_jobs do
        fill_in 'E-mail:', with: viewer_email
        click_on 'Generate Invitation'
      end
    end

    #
    # User accepts the invitation and creates and confirms their account
    #
    Capybara.using_session(:user) do
      open_email(viewer_email)
      current_email.find('a[href*="invitation"]').click
      clear_emails

      fill_in 'Password', with: 'testpassword'
      fill_in 'Password confirmation', with: 'testpassword'
      click_on 'Sign up'

      open_email(viewer_email)
      current_email.click_link 'Confirm my account'
      clear_emails

      fill_in 'Email', with: viewer_email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content?("Logged in as #{viewer_email}"), 'User should have an active session'
    end

    #
    # Administrator promotes the User to have the "admin" permission
    #
    Capybara.using_session(:admin) do
      visit admin_path

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Manage'
      end

      check 'manage_users'
      click_on "Update #{viewer_email}"
    end

    #
    # User verifies that they have received the "admin" permission
    #
    Capybara.using_session(:user) do
      visit root_path

      # The user needs to re-login at this point.
      click_on 'Login'
      fill_in 'Email', with: viewer_email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_link?('Admin'), 'User should have admin permissions'
    end

    #
    # Administrator removes the User's "admin" permission
    #
    Capybara.using_session(:admin) do
      visit admin_path

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Manage'
      end

      uncheck 'manage_users'
      click_on "Update #{viewer_email}"
    end

    #
    # User verifies that the admin permission has been removed
    #
    Capybara.using_session(:user) do
      visit root_path
      refute page.has_link?('Admin'), 'User should not have admin permissions'
    end

    #
    # Administrator deletes the User's account
    #
    Capybara.using_session(:admin) do
      visit admin_path

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Delete Account'
      end
    end

    #
    # User is logged out from the deleted account and prevented from logging back in
    #
    Capybara.using_session(:user) do
      visit root_path
      refute page.has_content?("Logged in as #{viewer_email}"), 'User should NOT have an active session'

      click_on 'Login'

      fill_in 'Email', with: viewer_email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content?('Invalid Email or password.'), 'User should not be able to log in'
    end
  end
end
