require 'mechanize'

module Fairbanks
  class Client
    MAIN_URL       = 'https://mac.fairbanksllc.com'
    LOGIN_URL      = "#{MAIN_URL}/login"
    DASHBOARD_URL  = "#{MAIN_URL}/manage"
    ROSTER_URL     = "#{DASHBOARD_URL}/participant/list.html"

    LOGIN_ACTION   = '/login/index.html'

    TEMP_PATH      = "#{Dir.pwd}/tmp/downloads"

    NOT_LOGGED_MSG = 'Not logged!'

    def initialize(options = {})
      @options = options
      @agent   = Mechanize.new
    end

    def download_presonal_roster(path = nil)
      unless login.link_with(text: 'Logout').nil?
        file_link     = roster_page.link_with(dom_class: 'export-excel')
        file          = @agent.get "#{MAIN_URL}/#{file_link.uri.to_s}"
        file.filename = path || "#{TEMP_PATH}/#{file.filename}"
        file.save!
      else
        msg = NOT_LOGGED_MSG
      end

      if msg.nil?
        { result: true, file: file.filename }
      else
        { result: false, errors: msg, file: path }
      end
    end

    def roster_page
      @agent.get ROSTER_URL
    end

    def login_page
      @agent.get LOGIN_URL
    end

    def login
      login_form = login_page.form_with(action: LOGIN_ACTION) do |f|
        f.field_with(name: 'username').value = @options[:login]
        f.field_with(name: 'password').value = @options[:password]
      end
      login_form.submit(login_form.button_with(value: 'Login'))
    end

    def logged_in?
      !roster_page.link_with(text: 'Logout').nil?
    end

  end
end
