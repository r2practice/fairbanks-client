require 'mechanize'

module Fairbanks
  class Client
    MAIN_URL       = 'https://mac.fairbanksllc.com'
    LOGIN_URL      = "#{MAIN_URL}/login"
    DASHBOARD_URL  = "#{MAIN_URL}/manage"
    ROSTER_URL     = "#{DASHBOARD_URL}/participant/"
    INVOICE_URL    = "#{DASHBOARD_URL}/finance/"

    LOGIN_ACTION   = '/login/index.html'

    TEMP_PATH      = "#{Dir.pwd}/tmp/downloads"

    NOT_LOGGED_MSG = 'Not logged!'
    QUARTER_NOT_FOUND_MSG = 'Quarter not found or wrong!'
    INVALID_DISTRICT = 'Invalid district name!'

    UPLOADER_FILE_TYPES = { invoice: 'Invoice', expenditures: 'Expenditures', ratedoc: 'RateDoc' }
    UPLOAD_PREFIX = 'moUpload'
    UPLOAD_COMPLETED_STATUS = 'complete'

    DISTRICTS_LINKS_CSS = 'table#district-view tr td.name a'

    def initialize(options = {})
      @options  = options
      @quarter  = @options[:quarter] || current_quarter
      @year     = @options[:year] || Time.now.year
      @district = @options[:district_name]
      @agent    = Mechanize.new
    end

    def upload_personal_data(files = {invoice: nil, expenditures: nil, ratedoc: nil})
      unless login.link_with(text: 'Logout').nil?
        return {error: INVALID_DISTRICT} if page_by_district(INVOICE_URL).nil?

        page = invoice_page_by_quarter
        if page.nil?
          msg = QUARTER_NOT_FOUND_MSG
        else
          files.each do |key, filename|
            return errors("File not found!", filename) unless File.exist?(filename)
            upload_page = page.link_with(href: /#{UPLOAD_PREFIX}#{UPLOADER_FILE_TYPES[key]}/).click
            upload_form = upload_page.forms.last
            upload_form.file_uploads.first.file_name = filename
            upload_form.submit(upload_form.buttons.first)
          end
        end
        logout
      else
        msg = NOT_LOGGED_MSG
      end

      msg.nil? ? { result: true } : { result: false, errors: msg }
    end

    def data_uploaded_for?(file_type = nil)
      return {error: NOT_LOGGED_MSG} if login.link_with(text: 'Logout').nil?
      return {error: INVALID_DISTRICT} if page_by_district(INVOICE_URL).nil?
      page = invoice_page_by_quarter
      upload_link = page.link_with(href: /#{UPLOAD_PREFIX}#{UPLOADER_FILE_TYPES[file_type]}/)
      upload_link.node.parent.children.last.name == 'p'
    end

    def ready_for_certify?
      UPLOADER_FILE_TYPES.all?{ |type| data_uploaded_for?(type.first) }
    end

    def personal_data_certified?
      return {error: NOT_LOGGED_MSG} if login.link_with(text: 'Logout').nil?
      return {error: INVALID_DISTRICT} if page_by_district(INVOICE_URL).nil?
      page = invoice_page_by_quarter
      certify_link = page.link_with(href: /moCertify/)
      unless certify_link.nil?
        certify_link.node.parent.attributes['class'].value.strip == UPLOAD_COMPLETED_STATUS
      else
        false
      end
    end

    def certify_personal_data
      return {error: NOT_LOGGED_MSG} if login.link_with(text: 'Logout').nil?
      return {error: INVALID_DISTRICT} if page_by_district(INVOICE_URL).nil?
      page = invoice_page_by_quarter
      certify_link = page.link_with(text: /Certify/)
      if ready_for_certify? && !certify_link.nil?
        certify_form = certify_link.click.forms.last
        certify_form.submit(certify_form.buttons.last)
      end
      {result: true}
    end

    def download_personal_roster(filename = nil)
      return errors("#{filename} not file!", filename) if !filename.nil? && File.directory?(filename)
      unless login.link_with(text: 'Logout').nil?
        return {error: INVALID_DISTRICT} if page_by_district(ROSTER_URL).nil?

        page = roster_page_by_quarter
        if page.nil?
          msg = QUARTER_NOT_FOUND_MSG
        else
          file = page.link_with(dom_class: 'export-excel').click
          file.filename = filename unless filename.nil?
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
      @agent.get "#{ROSTER_URL}/list.html"
    end

    def invoice_page
      @agent.get INVOICE_URL
    end

    def invoice_page_by_quarter
      form   = @agent.page.form_with(action: '/manage/finance/steps.html')
      option = form.field_with(name: 'sharsId').option_with(text: quarter_option_text('Open'))
      return nil if option.nil?
      option.click
      form.submit
    end

    def roster_page_by_quarter
      roster_page
      form   = @agent.page.form_with(action: 'manage/participant/list.html')
      option = form.field_with(name: 'quarterId').option_with(text: quarter_option_text)
      return nil if option.nil?
      option.click
      form.submit
    end

    def page_by_district(page_url)
      page = @agent.get page_url
      if has_districts?
        return nil unless has_district?(@district)
        district_link(@district).click
      end
      page
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

    def has_districts?
      login && roster_page && districts_links.any?
    end

    def has_district?(district_name)
      login && roster_page && !district_link(district_name).nil?
    end

    def districts
      login && roster_page ? districts_links.map(&:text) : []
    end

    private

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

    def districts_links
      return [] if @agent.page.nil?
      html  = Nokogiri::HTML(@agent.page.body, 'UTF-8')
      html.css(DISTRICTS_LINKS_CSS)
    end

    def district_link(district_name)
      links = districts_links
      return nil if links.empty?
      link = links.at("a[title='View #{district_name}']")
      return nil if link.nil?

      @agent.page.link_with(href: link['href'])
    end

  end
end
