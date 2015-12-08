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

TODO: Write usage instructions here


Download personal roster:

```ruby
client = Fairbanks::Client.new({login: 'username', password: 'password', quarter: 2})
client.download_presonal_roster('path-to-file/roster.xls')
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
