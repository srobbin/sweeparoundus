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
      expect(mail.from).to eq([ENV["DEFAULT_EMAIL"]])
      expect(mail.to).to eq(["Ward01@cityofchicago.org"])
      expect(mail.subject).to eq("Street sweeping reminder resource - #{Time.current.year} schedules live")
    end

    it 'includes the alderperson name and ward in the HTML body' do
      expect(html_body).to include("Dear Alderperson La Spata")
      expect(html_body).to include("Ward 1")
    end

    it 'includes the site name and URL in the HTML body' do
      expect(html_body).to include(ENV["SITE_NAME"])
      expect(html_body).to include(ENV["SITE_URL"])
    end

    it 'includes the schedules-live announcement in the HTML body' do
      expect(html_body).to include("#{Time.current.year} Chicago street sweeping schedules are now live")
    end

    it 'includes the unaffiliated disclaimer in the HTML body' do
      expect(html_body).to include("is not affiliated with the City of")
      expect(html_body).to include("Department of Streets and Sanitation")
    end

    it 'includes the correct content in the text body' do
      expect(text_body).to include("Dear Alderperson La Spata")
      expect(text_body).to include("Ward 1")
      expect(text_body).to include("#{Time.current.year} Chicago street sweeping schedules are now live")
      expect(text_body).to include("is not affiliated with the City of Chicago")
    end
  end
end
