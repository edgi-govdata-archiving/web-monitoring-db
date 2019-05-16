require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  test "Invite, register, confirm, promote, demote, delete" do
    admin = users(:admin_user)
    viewer_email = 'viewer@example.com'

    Capybara.using_session(:admin) do
      visit root_path

      click_on "Login"

      fill_in 'Email', with: admin.email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content? "Logged in as #{admin.email}"
      click_on 'Admin'

      perform_enqueued_jobs do
        fill_in 'E-mail:', with: viewer_email
        click_on 'Generate Invitation'
      end
    end

    Capybara.using_session(:viewer) do
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

      assert page.has_content? "Logged in as viewer@example.com"
    end

    Capybara.using_session(:admin) do
      visit admin_path
      assert page.has_content? "Logged in as #{admin.email}"

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Promote to admin'
      end
    end

    Capybara.using_session(:viewer) do
      visit root_path

      # TODO: Signing in again should not be necessary.
      click_on 'Login'
      fill_in 'Email', with: viewer_email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content? 'Admin'
    end

    Capybara.using_session(:admin) do
      visit admin_path
      assert page.has_content? "Logged in as #{admin.email}"

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Demote from admin'
      end
    end

    Capybara.using_session(:viewer) do
      visit root_path
      refute page.has_content? 'Admin'
    end

    Capybara.using_session(:admin) do
      visit admin_path

      user_row = page.all('tr').find { |tr| tr.has_content? viewer_email }
      within user_row do
        click_on 'Delete Account'
      end
    end

    Capybara.using_session(:viewer) do
      visit root_path
      click_on 'Login'

      fill_in 'Email', with: viewer_email
      fill_in 'Password', with: 'testpassword'
      click_on 'Log in'

      assert page.has_content? 'Invalid Email or password.'
    end
  end
end
