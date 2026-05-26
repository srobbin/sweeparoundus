# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlertMailer, type: :mailer do
  include JwtHelper

  let!(:area) { create :area }
  let!(:sweep) { create :sweep, area: area }
  let(:html_body) do
    mail.body.parts.find { |p| p.content_type.match 'text/html' }.body.raw_source
  end
  let(:text_body) do
    mail.body.parts.find { |p| p.content_type.match 'text/plain' }.body.raw_source
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
      expect(mail.from).to eq([ 'info@wethesweeple.com' ])
      expect(mail.subject).to eq("Your #{Time.current.year} sweep dates are ready—check your schedule")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include(alert.street_address)
      expect(html_body).to include(area.name)
      expect(html_body).to include("The #{Time.current.year} sweeping schedule is live.")
      expect(html_body).to include("Your first sweep is <strong>#{sweep.date_1.strftime('%a, %b %-d')}</strong>")
      expect(html_body).to include('Moved recently?')
      expect(html_body).to include('Manage your subscriptions')
      expect(html_body).to include("View your #{Time.current.year} schedule")
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(ApplicationMailer::DISCLAIMER))
    end

    it 'embeds a valid manage JWT in the HTML body' do
      token = html_body.match(/subscriptions\/manage\?t=([^"&\s]+)/)[1]
      decoded = decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(alert.email)
      expect(decoded["purpose"]).to eq("manage")
      expect(decoded["exp"]).to be_within(5).of(60.days.from_now.to_i)
    end

    it 'includes the manage link in the text body' do
      expect(text_body).to include('Manage your subscriptions')
      expect(text_body).to include(manage_subscriptions_url.to_s)
    end

    it 'includes the coffee block in the HTML body' do
      expect(html_body).to include('Buy us a coffee')
      expect(html_body).to include('Enjoying this free service?')
    end

    context 'when no sweeps exist yet for the year' do
      before { area.sweeps.destroy_all }

      it 'renders the carry-over fallback copy and omits a first-sweep date' do
        expect(html_body).to include("carried over for the #{Time.current.year} season")
        expect(html_body).not_to include('Your first sweep is')
        expect(text_body).to include("carried over for the #{Time.current.year} season")
      end
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
      expect(mail.from).to eq([ 'info@wethesweeple.com' ])
      expect(mail.subject).to eq("Confirm your #{ENV["SITE_NAME"]} alerts for #{alert.street_address}")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Confirm your sweeping alert')
      expect(html_body).to include('We received a request to subscribe')
      expect(html_body).to include(alert.email)
      expect(html_body).to include("<strong>#{CGI.escapeHTML(alert.street_address)} (#{area.name})</strong>")
      expect(html_body).to include('Confirm your subscription')
      expect(html_body).to include(confirm_area_alerts_url(area))
      expect(html_body).to include("We'll email you the day before each sweep")
      expect(html_body).to include("Didn't request this?")
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(ApplicationMailer::DISCLAIMER))
    end

    it 'encodes the raw street address in the confirmation JWT so the DB lookup succeeds' do
      token = html_body.match(/confirm\?t=([^"&\s]+)/)[1]
      decoded = decode_jwt(token)

      expect(decoded["sub"]).to eq(alert.email)
      expect(decoded["street_address"]).to eq(alert.street_address)
    end

    it 'omits the coffee block' do
      expect(html_body).not_to include('Buy us a coffee')
    end

    context 'when alert has no street address' do
      let!(:alert) { create :alert, :unconfirmed, area: area }

      it 'falls back to the area name in the subject and body' do
        expect(mail.subject).to eq("Confirm your #{ENV["SITE_NAME"]} alerts for #{area.name}")
        expect(html_body).to include("<strong>#{area.name}</strong>")
      end
    end

    context 'with neighbor alerts' do
      let!(:neighbor_area) { create :area, number: 8, ward: 28, slug: 'ward-28-sweep-area-8', shortcode: 'W28A8' }
      let!(:neighbor_alert) { create :alert, :unconfirmed, :with_address, area: neighbor_area, email: alert.email }
      let(:mail) do
        described_class
          .with(alert: alert, neighbor_alerts: [ neighbor_alert ])
          .confirm
          .deliver_now
      end

      it 'pluralizes the subject and lists each area' do
        expect(mail.subject).to eq("Confirm your 2 #{ENV["SITE_NAME"]} subscriptions")
        expect(html_body).to include(neighbor_area.name)
      end
    end
  end

  describe '#reminder email' do
    let!(:alert) { create :alert, :confirmed, :with_address, area: area }
    let(:mail) do
      described_class
        .with(alert: alert, sweep: sweep)
        .reminder
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq([ 'info@wethesweeple.com' ])
      expect(mail.subject).to eq("Tomorrow: street sweeping at #{alert.street_address}")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include(CGI.escapeHTML(alert.street_address))
      expect(html_body).to include(area_url(area))
      expect(html_body).to include('Street sweeping starts tomorrow.')
      expect(html_body).to include(sweep.date_1.strftime('%a, %b %-d'))
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(CGI.escapeHTML(ApplicationMailer::DISCLAIMER))
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('Manage subscriptions')
    end

    it 'embeds a valid manage JWT in the HTML body' do
      token = html_body.match(/subscriptions\/manage\?t=([^"&\s]+)/)[1]
      decoded = decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(alert.email)
      expect(decoded["purpose"]).to eq("manage")
      expect(decoded["exp"]).to be_a(Integer)
    end

    it 'includes the manage link in the text body' do
      expect(text_body).to include('Manage subscriptions')
      expect(text_body).to include(manage_subscriptions_url.to_s)
    end

    it 'includes the coffee block' do
      expect(html_body).to include('Buy us a coffee')
      expect(html_body).to include('Enjoying this free service?')
    end

    context 'when alert has no street address' do
      let!(:alert) { create :alert, :unconfirmed, area: area }

      it 'falls back to the area name in the subject and chip' do
        expect(mail.subject).to eq("Tomorrow: street sweeping in #{area.name}")
        expect(html_body).to include(area.name)
        expect(html_body).to include(area_url(area))
      end
    end
  end

  describe '#sweeping_data_delayed email' do
    let!(:alert) { create :alert, :confirmed, :with_address, area: area }
    let(:mail) do
      described_class
        .with(alert: alert)
        .sweeping_data_delayed
        .deliver_now
    end

    it 'has the right attributes' do
      expect(mail.from).to eq([ 'info@wethesweeple.com' ])
      expect(mail.subject).to eq("#{Time.current.year} Chicago street sweeping alerts are delayed")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include('Hello,')
      expect(html_body).to include("you subscribed to Chicago street sweeping alerts")
      expect(html_body).to include(alert.street_address)
      expect(html_body).to include("delayed the release of the 2026 street sweeping zone data")
      expect(html_body).to include("We The Sweeple (unaffiliated with the City)")
      expect(html_body).to include("Department of Streets and Sanitation page")
      expect(html_body).to include("alerts are up and running")
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include(unsubscribe_area_alerts_url(area))
      expect(html_body).to include('Manage subscriptions')
    end

    it 'embeds a valid manage JWT in the HTML body' do
      token = html_body.match(/subscriptions\/manage\?t=([^"&\s]+)/)[1]
      decoded = decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(alert.email)
      expect(decoded["purpose"]).to eq("manage")
      expect(decoded["exp"]).to be_a(Integer)
    end

    it 'includes the manage link in the text body' do
      expect(text_body).to include('Manage subscriptions')
      expect(text_body).to include(manage_subscriptions_url.to_s)
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
      expect(mail.from).to eq([ 'info@wethesweeple.com' ])
      expect(mail.subject).to eq("Your #{ENV["SITE_NAME"]} subscription for #{area.name} was canceled—here's why")
      expect(mail.to).to include(alert.email)
      expect(html_body).to include("Your #{ENV["SITE_NAME"]} subscription for #{area.name} has been canceled.")
      expect(html_body).to include("Each year, the City of Chicago redraws its sweeping areas")
      expect(html_body).to include('Re-subscribe')
      expect(html_body).to include(ENV["SITE_URL"])
      expect(html_body).to include('Day-before reminders')
      expect(html_body).to include('Map of your sweep zone')
      expect(html_body).to include('Always free')
      expect(html_body).to include('Cheers,')
      expect(html_body).to include(ENV["SITE_NAME"])
    end
  end
end
