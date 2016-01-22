# Fairbanks::Client

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'fairbanks-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fairbanks-client

## Usage

Download personal roster:

```ruby
client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2})
client.download_personal_roster('path-to-file/roster.xls')
```

Upload personal data:

```ruby
client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2})
client.upload_personal_data({invoice: claim_file, expenditures: cert_file, ratedoc: mv_file})
```

or:

```ruby
client.upload_personal_data({expenditures: cert_file})
```

Check personal data uploading:

```ruby
client.data_uploaded_for?(:invoice) # values: :invoice, :expenditures, :ratedoc
client.ready_for_certify? # check upload all files
client.personal_data_certified? # check data sertification

```

Sertify personal data:

```ruby
client.certify_personal_data
```

Accounts with districs:

```ruby
client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2, district_name: 'wrong_name'})
client.download_personal_roster('path-to-file/roster.xls') #=> {:error=>"Invalid district name!"}

client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2, district_name: 'good_name'})
client.download_personal_roster('roster.xls') #=> => {:result=>true, :file=>"roster.xls"}

```
districts checking:

```ruby
client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2, district_name: 'wrong_name'})

client.has_districts? #=> true or false
client.has_district?(district_name) #=> true or false
client.districts #=> array

```