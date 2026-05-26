# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WardOfficeMailer, type: :mailer do
  describe '#schedules_live email' do
    let(:mail) do
      described_class
        .with(name: "La Spata", email: "Ward01@cityofchicago.org", ward: "1")
        .schedules_live
        .deliver_now
    end

    let(:html_body) do
      mail.body.parts.find { |p| p.content_type.match 'text/html' }.body.raw_source
    end

    let(:text_body) do
      mail.body.parts.find { |p| p.content_type.match 'text/plain' }.body.raw_source
    end

    it 'has the right attributes' do
      expect(mail.from).to eq([ ENV["DEFAULT_EMAIL"] ])
      expect(mail.to).to eq([ "Ward01@cityofchicago.org" ])
      expect(mail.subject).to eq("Free #{Time.current.year} street sweeping reminders for your Ward 1 constituents")
    end

    it 'includes the alderperson name and ward in the HTML body' do
      expect(html_body).to include("Dear Alderperson La Spata")
      expect(html_body).to include("Ward 1")
    end

    it 'includes the site name and URL in the HTML body' do
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
    end

    it 'opens with the value proposition for residents' do
      expect(html_body).to include("offers free, opt-in email")
      expect(html_body).to include("the day before their")
      expect(html_body).to include("street is swept")
      expect(html_body).to include("reduce parking tickets")
    end

    it 'includes the schedules-live announcement in the HTML body' do
      expect(html_body).to include("#{Time.current.year} Chicago street sweeping schedules are now live")
    end

    it 'renders the value-prop bullets' do
      expect(html_body).to include("No app, no account")
      expect(html_body).to include("Free for residents and for your office")
      expect(html_body).to include("Covers all 50 wards")
    end

    it 'includes the shareable copy blockquote' do
      expect(html_body).to include("Sign up for free street sweeping reminders")
    end

    it 'includes the primary visit-site CTA' do
      expect(html_body).to include("Visit #{ENV["SITE_NAME"]}")
      expect(html_body).to include(ENV["SITE_URL"])
    end

    it 'includes the unaffiliated disclaimer in the HTML body' do
      expect(html_body).to include("is not affiliated with the City of")
      expect(html_body).to include("Department of Streets and Sanitation")
    end

    it 'includes the coffee block' do
      expect(html_body).to include("Buy us a coffee")
    end

    it 'includes the correct content in the text body' do
      expect(text_body).to include("Dear Alderperson La Spata")
      expect(text_body).to include("Ward 1")
      expect(text_body).to include("#{Time.current.year} Chicago street sweeping schedules are now live")
      expect(text_body).to include("is not affiliated with the City of Chicago")
    end
  end

  describe '#sweeping_data_delayed email' do
    let(:mail) do
      described_class
        .with(name: "La Spata", email: "Ward01@cityofchicago.org", ward: "1")
        .sweeping_data_delayed
        .deliver_now
    end

    let(:html_body) do
      mail.body.parts.find { |p| p.content_type.match 'text/html' }.body.raw_source
    end

    let(:text_body) do
      mail.body.parts.find { |p| p.content_type.match 'text/plain' }.body.raw_source
    end

    it 'has the right attributes' do
      expect(mail.from).to eq([ ENV["DEFAULT_EMAIL"] ])
      expect(mail.to).to eq([ "Ward01@cityofchicago.org" ])
      expect(mail.subject).to eq("#{Time.current.year} Chicago street sweeping data delayed")
    end

    it 'includes the alderperson name and ward in the HTML body' do
      expect(html_body).to include("Dear Alderperson La Spata")
      expect(html_body).to include("Ward 1")
    end

    it 'includes the delay announcement in the HTML body' do
      expect(html_body).to include("delayed the release of the 2026 street sweeping zone data")
      expect(html_body).to include("Department of Streets and Sanitation page")
    end

    it 'includes the site name in the HTML body' do
      expect(html_body).to include(ENV["SITE_NAME"])
    end

    it 'includes the unaffiliated disclaimer in the HTML body' do
      expect(html_body).to include("is not affiliated with the City of Chicago")
    end

    it 'includes the correct content in the text body' do
      expect(text_body).to include("Dear Alderperson La Spata")
      expect(text_body).to include("Ward 1")
      expect(text_body).to include("delayed the release of the 2026 street sweeping zone data")
      expect(text_body).to include("is not affiliated with the City of Chicago")
    end
  end
end
