# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlertMailer, type: :mailer do
  let!(:area) { create :area }
  let!(:sweep) { create :sweep, area: area }
  let(:html_body) do
    mail.body.parts.find { |p| p.content_type.match 'text/html' }.body.raw_source
  end 
  
  describe '#confirm email' do
    let!(:alert) { create :alert, :unconfirmed, :with_address, area: area }
    let(:mail) do
      described_class
        .with(alert: alert, sweep: sweep)
        .confirm
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq(['info@wethesweeple.com'])
      expect(mail.subject).to eq('Please confirm your subscription to Ward 28, Sweep Area 7')
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Hello,')
      expect(html_body).to include('You are receiving this email because we have received a request to subscribe')
      expect(html_body).to include(alert.email)
      expect(html_body).to include("to Chicago street sweeping alerts for <strong>#{alert.street_address} (#{area.name})</strong>.")
      expect(html_body).to include('Alerts will be sent out one day prior to a scheduled street sweeping.')
      expect(html_body).to include(confirm_area_alerts_url(area))
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('https://www.wethesweeple.com')
      expect(html_body).to include("Copyright #{Time.current.year} We The Sweeple")
    end

    context 'when alert has no street address' do
      let!(:alert) { create :alert, :unconfirmed, area: area }

      it 'has the right attributes' do
        expect(html_body).to include("to Chicago street sweeping alerts for <strong>#{area.name}</strong>.")
      end
    end
  end

  describe '#reminder email' do
    let!(:alert) { create :alert, :confirmed, :with_address, area: area }
    let(:mail) do
      described_class
        .with(alert: alert, sweep: sweep)\
        .reminder
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq(['info@wethesweeple.com'])
      expect(mail.subject).to eq('Street sweeping alert for Ward 28, Sweep Area 7')
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Hello,')
      expect(html_body).to include("This is a reminder that street sweeping for #{alert.street_address}")
      expect(html_body).to include(area_url(area))
      expect(html_body).to include('will begin tomorrow.')
      expect(html_body).to include(Date.tomorrow.strftime('%B %-d'))
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include('Note: This site does not guarantee that the information presented is accurate, or that notifications will be delivered on a timely basis. Please consult the Department of Streets and Sanitation website and street signage for parking information.')
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('https://www.wethesweeple.com')
      expect(html_body).to include("Copyright #{Time.current.year} We The Sweeple")
    end

    context 'when alert has no street address' do
      let!(:alert) { create :alert, :unconfirmed, area: area }

      it 'has the right attributes' do
        expect(html_body).to include("This is a reminder that street sweeping for <a href=")
      end
    end
  end

  describe '#deleted_notification email' do
    let!(:alert) { create :alert, :confirmed, area: area }
    let(:mail) do
      described_class
        .with(alert: alert)
        .deleted_notification
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq(['info@wethesweeple.com'])
      expect(mail.subject).to eq('Your street sweeping alert subscription has been canceled')
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Hello,')
      expect(html_body).to include("We've just updated the Chicago street sweeping schedules for the #{Time.current.year} season, and wanted to let you know that your subscription for <strong>#{area.name}</strong> has been canceled. (This is because your subscription either was unconfirmed or did not have a specific street address, and because the City's sweeping areas often change from year to year.)")
      expect(html_body).to include("If you'd like to continue receiving alerts for this (or another) area,")
      expect(html_body).to include(root_url)
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include('https://www.wethesweeple.com')
    end
  end
end
