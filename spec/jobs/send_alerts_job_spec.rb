require "rails_helper"

RSpec.describe SendAlertsJob do
  let!(:area) { create(:area) }

  describe "#perform" do
    context "when a sweep has date_1 = tomorrow" do
      let!(:sweep) { create(:sweep, area: area, date_1: Date.tomorrow) }
      let!(:confirmed_alert) { create(:alert, :confirmed, area: area) }

      it "sends a reminder email to confirmed subscribers" do
        mailer_dbl = double
        allow(AlertMailer).to receive(:with).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:reminder).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later)

        described_class.new.perform

        expect(AlertMailer).to have_received(:with).with(alert: confirmed_alert, sweep: sweep)
        expect(mailer_dbl).to have_received(:reminder)
        expect(mailer_dbl).to have_received(:deliver_later)
      end
    end

    context "when a sweep has date_1 != tomorrow" do
      let!(:sweep) { create(:sweep, area: area, date_1: Date.tomorrow + 5) }
      let!(:confirmed_alert) { create(:alert, :confirmed, area: area) }

      it "does not send reminders" do
        expect(AlertMailer).not_to receive(:with)

        described_class.new.perform
      end
    end

    context "when only date_2 is tomorrow" do
      let!(:sweep) { create(:sweep, area: area, date_1: Date.current, date_2: Date.tomorrow) }
      let!(:confirmed_alert) { create(:alert, :confirmed, area: area) }

      it "does not send reminders (only date_1 is checked)" do
        expect(AlertMailer).not_to receive(:with)

        described_class.new.perform
      end
    end

    context "with only unconfirmed alerts" do
      let!(:sweep) { create(:sweep, area: area, date_1: Date.tomorrow) }
      let!(:unconfirmed_alert) { create(:alert, :unconfirmed, area: area) }

      it "does not send reminders to unconfirmed subscribers" do
        expect(AlertMailer).not_to receive(:with)

        described_class.new.perform
      end
    end

    context "with no sweeps tomorrow" do
      it "does not send any reminders" do
        expect(AlertMailer).not_to receive(:with)

        described_class.new.perform
      end
    end
  end
end
