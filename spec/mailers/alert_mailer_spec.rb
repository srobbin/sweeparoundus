# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlertMailer, type: :mailer do
  let!(:area) { create :area }
  let!(:sweep) { create :sweep, area: area }
  let(:html_body) do
    mail.body.parts.find { |p| p.content_type.match 'text/html' }.body.raw_source
  end 
  
  describe '#annual_schedule_live email' do
    let!(:alert) { create :alert, :with_address, area: area }
    let(:mail) do
      described_class
        .with(alert: alert)
        .annual_schedule_live
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq(['info@wethesweeple.com'])
      expect(mail.subject).to eq("#{Time.current.year} street sweeping schedule is now live")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Hello,')
      expect(html_body).to include("You are receiving this email because you subscribed to Chicago street sweeping alerts for the following street address: #{alert.street_address}")
      expect(html_body).to include('If you no longer want to receive alerts for this address,')
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('If you have moved and wish to receive alerts for a new address,')
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(AlertMailer::DISCLAIMER))
      expect(html_body).to include("Copyright #{Time.current.year} We The Sweeple")
    end
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
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(AlertMailer::DISCLAIMER))
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
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
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(AlertMailer::DISCLAIMER))
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
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
      expect(html_body).to include("We've just updated the Chicago street sweeping schedules for the #{Time.current.year} season, and wanted to let you know that your subscription for <strong>#{area.name}</strong> has been canceled. (This is because your subscription was unconfirmed and/or did not have a specific street address, and because the City's sweeping areas often change from year to year.)")
      expect(html_body).to include("If you'd like to continue receiving alerts for this (or another) area,")
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
    end
  end
end
