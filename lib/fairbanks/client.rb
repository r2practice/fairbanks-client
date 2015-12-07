require 'mechanize'

module Fairbanks
  class Client
    MAIN_URL       = 'https://mac.fairbanksllc.com'
    LOGIN_URL      = "#{MAIN_URL}/login"
    DASHBOARD_URL  = "#{MAIN_URL}/manage"
    ROSTER_URL     = "#{DASHBOARD_URL}/participant/list.html"
    INVOICE_URL    = "#{DASHBOARD_URL}/finance/"

    LOGIN_ACTION   = '/login/index.html'

    TEMP_PATH      = "#{Dir.pwd}/tmp/downloads"

    NOT_LOGGED_MSG = 'Not logged!'
    QUARTER_NOT_FOUND_MSG = 'Quarter not found or wrong!'

    UPLOADER_FILE_TYPES = { invoice: 'Invoice', expenditures: 'Expenditures', ratedoc: 'RateDoc' }
    UPLOAD_PREFIX = 'moUpload'

    def initialize(options = {})
      @options = options
      @quarter = @options[:quarter] || current_quarter
      @year    = @options[:year] || Time.now.year
      @agent   = Mechanize.new
    end

    def upload_personal_data(files = {invoice: nil, expenditures: nil, ratedoc: nil})
      unless login.link_with(text: 'Logout').nil?
        page = invoice_page_by_quarter
        if page.nil?
          msg = QUARTER_NOT_FOUND_MSG
        else
          files.each do |key, filename|
            return errors("File not found!", filename) unless File.exist?(filename)
            upload_page = page.link_with(href: /#{UPLOAD_PREFIX}#{UPLOADER_FILE_TYPES[key]}/).click
            upload_form = upload_page.forms.last
            upload_form.file_uploads.first.file_name = filename
            upload_form.submit
          end
        end
        logout
      else
        msg = NOT_LOGGED_MSG
      end

      msg.nil? ? { result: true } : { result: false, errors: msg }
    end

    def download_presonal_roster(filename = nil)
      filename = filename || default_filename
      return errors("#{filename} not file!", filename) if File.directory?(filename)
      unless login.link_with(text: 'Logout').nil?
        page = roster_page_by_quarter
        if page.nil?
          msg = QUARTER_NOT_FOUND_MSG
        else
          file_link     = page.link_with(dom_class: 'export-excel')
          file          = @agent.get "#{MAIN_URL}/#{file_link.uri.to_s}"
          file.filename = filename
          file.save!
        end
        logout
      else
        msg = NOT_LOGGED_MSG
      end

      msg.nil? ? { result: true, file: file.filename } : errors(msg, filename)
    end

    def errors(msg, filename)
      { result: false, errors: msg, file: filename }
    end

    def roster_page
      @agent.get ROSTER_URL
    end

    def invoice_page
      @agent.get INVOICE_URL
    end

    def invoice_page_by_quarter
      form   = invoice_page.form_with(action: '/manage/finance/steps.html')
      option = form.field_with(name: 'sharsId').option_with(text: quarter_option_text('Open'))
      return nil if option.nil?
      option.click
      form.submit
    end

    def roster_page_by_quarter
      form   = roster_page.form_with(action: 'manage/participant/list.html')
      option = form.field_with(name: 'quarterId').option_with(text: quarter_option_text)
      return nil if option.nil?
      option.click
      form.submit
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

    def logout
      roster_page.link_with(text: 'Logout').click
    end

    def current_quarter
      ((Time.now.month - 1) / 3) + 1
    end

    def quarter_option_text(type = 'Closed')
      space = type == 'Closed' ? '' : ' '
      "#{type} Quarter: #{space}Q#{@quarter}-#{Date.new(@year.to_i).strftime('%y')}"
    end

    def default_filename
      "#{TEMP_PATH}/roster_for_#{@options[:login]}_q#{@quarter}_#{@year}_#{Time.now.strftime("%Y-%m-%d_%H:%M:%S")}.xls"
    end

  end
end
