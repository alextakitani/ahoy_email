ActiveRecord::Schema.define do
  create_table :ahoy_messages, force: true do |t|
    t.references :user, polymorphic: true
    t.text :to
    t.string :mailer
    t.text :subject
    t.datetime :sent_at

    # opens & clicks
    t.string :token
    t.datetime :opened_at
    t.datetime :clicked_at

    # extra
    t.integer :coupon_id

    # legacy
    t.text :content
    t.string :utm_source
    t.string :utm_medium
    t.string :utm_term
    t.string :utm_content
    t.string :utm_campaign
  end

  create_table :ahoy_campaigns do |t|
    t.string :name
    t.integer :total_sent, default: 0

    # opens
    t.integer :total_opens, default: 0
    t.integer :unique_opens, default: 0
    t.binary :open_data

    # clicks
    t.integer :total_clicks, default: 0
    t.integer :unique_clicks, default: 0
    t.binary :click_data

    t.datetime :created_at
  end

  add_index :ahoy_campaigns, [:name], unique: true

  create_table :ahoy_urls do |t|
    t.references :campaign, index: false
    t.string :url
    t.integer :total_clicks, default: 0
    t.integer :unique_clicks, default: 0
    t.binary :click_data
  end

  add_index :ahoy_urls, [:campaign_id, :url], unique: true

  create_table :users, force: true do |t|
    t.string :email
  end
end
