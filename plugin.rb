# name: Crowd
# about: Authenticate with discourse with Crowd
# version: 0.2.0
# author: Harri Salokorpi

require 'rubygems'

gem 'addressable', '2.3.5', :require => false
gem 'omniauth_crowd', '2.2.2'

class CrowdAuthenticator < ::Auth::Authenticator

  def name
    'crowd'
  end

  def after_authenticate(auth_token)

    result = Auth::Result.new

    data = auth_token[:info]

    result.username = auth_token["uid"]
    result.name = data["name"]
    result.email = data["email"]

    # plugin specific data storage
    current_info = ::PluginStore.get("crowd", "crowd_uid_#{result.username}")

    user = User.find_by_email(result.email)
    if user.nil?
      Rails.logger.warn "Creating new user"
      user = User.create(name: result.name,
                         email: result.email,
                         username: result.username,
                         approved: true)
      ::PluginStore.set("crowd", "crowd_uid_#{user.username}", {user_id: user.id})
      result.email_valid = true
    end

    result.user =
        if current_info
          Rails.logger.warn "Updating result user from found user"
          user
        elsif user = User.where(username: result.username).first
          Rails.logger.warn "User not logged in, marking approved"
          # User has been created, but not logged in
          user.update_attribute(:approved, true)
          ::PluginStore.set("crowd", "crowd_uid_#{result.username}", {user_id: user.id})
          user
	else
          Rails.logger.warn "Passed all user checks!"
        end

    result
  end

  def after_create_account(user, auth)
    user.update_attribute(:approved, true)
    ::PluginStore.set("crowd", "crowd_uid_#{auth[:username]}", {user_id: user.id})
  end

  def register_middleware(omniauth)
    unless SiteSetting.crowd_sso_url.empty?
      omniauth.provider :crowd,
         :crowd_server_url => SiteSetting.crowd_sso_url,
         :application_name => SiteSetting.crowd_sso_application_name,
         :application_password => SiteSetting.crowd_sso_application_password
    end
  end
end

auth_provider :title => 'with Crowd',
              :message => 'Log in via Crowd.',
              :frame_width => 920,
              :frame_height => 800,
              :authenticator => CrowdAuthenticator.new

register_css <<CSS

.btn-social.crowd {
  background: #70BA61;
}

.btn-social.crowd:before {
  font-family: Ubuntu;
  content: "C";
}

CSS
