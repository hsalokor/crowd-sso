# name: Crowd
# about: Authenticate with discourse with Crowd
# version: 0.1.0
# author: Harri Salokorpi

require 'rubygems'

gem 'addressable', '2.3.5', :require => false
gem 'omniauth_crowd', '2.2.2'

class CrowdAuthenticator < ::Auth::Authenticator

  def name
    'crowd'
  end

  def after_authenticate(auth_token)

    Rails.logger.info "Auth token" + auth_token.inspect

    result = Auth::Result.new

    data = auth_token[:info]

    result.username = data["user"]
    result.name = name = data["name"]
    result.email = name = data["email"]

    crowd_user_id = auth_token["user"]

    # plugin specific data storage
    current_info = ::PluginStore.get("crowd", "crowd_uid_#{result.username}")

    user = User.create(name: result.name,
                       email: result.email,
                       username: result.username,
                       approved: true)
    ::PluginStore.set("crowd", "crowd_uid_#{user.username}", {user_id: user.id})
    result.email_valid = true

    result.user =
        if current_info
          User.where(id: current_info[:user_id]).first
        elsif user = User.where(username: result.username).first
          # User has been created, but not logged in
          user.update_attribute(:approved, true)
          ::PluginStore.set("crowd", "crowd_uid_#{result.username}", {user_id: user.id})
          user
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
         :crowd_server_url => SiteSettings.crowd_sso_url,
         :application_name => SiteSettings.crowd_sso_application_name,
         :application_password => SiteSettings.crowd_sso_application_password
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
  content: "Crowd";
}

CSS