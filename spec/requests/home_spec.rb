require "rails_helper"

RSpec.describe "Home", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /" do
    it "renders the home page" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    context "during the 2026 extended season (Nov 19-Dec 17)" do
      it "shows the extended sweeping message" do
        travel_to Date.new(2026, 12, 15) do
          get root_path

          expect(response.body).to include("SWEEPING EXTENDED THROUGH DEC 17")
          expect(response.body).to include("will not be updated")
        end
      end
    end

    context "after the extended season (sweeping done for year)" do
      it "shows the off-season message" do
        travel_to Date.new(2026, 12, 18) do
          get root_path

          expect(response.body).to include("SWEEP YOU NEXT YEAR")
        end
      end
    end

    {
      Date.new(2026, 11, 18) => false,
      Date.new(2026, 11, 19) => true,
      Date.new(2026, 12, 17) => true,
      Date.new(2026, 12, 18) => false,
      Date.new(2027, 12, 1) => false
    }.each do |date, extended|
      it "shows the extension only within its date range on #{date}" do
        travel_to date do
          get root_path

          if extended
            expect(response.body).to include("SWEEPING EXTENDED THROUGH DEC 17")
            expect(response.body).to include("will not be updated")
          else
            expect(response.body).not_to include("SWEEPING EXTENDED THROUGH DEC 17")
            expect(response.body).not_to include("Extended season through Dec. 17:")
            expect(response.body).to include("SWEEP YOU NEXT YEAR") if date.month == 12
          end
        end
      end
    end

    # context "before March 31 (beginning of year)" do
    #   it "shows the coming soon message when schedules are not yet live" do
    #     travel_to Date.new(2026, 2, 15) do
    #       get root_path

    #       expect(response.body).to include("SCHEDULES COMING SOON")
    #     end
    #   end
    # end

    context "after March 31 (sweeping season)" do
      it "shows the schedules live message" do
        travel_to Date.new(2026, 5, 15) do
          get root_path

          expect(response.body).to include("SCHEDULES NOW LIVE")
        end
      end
    end

    it "includes the subscription carry-over note" do
      travel_to Date.new(2026, 5, 15) do
        get root_path

        expect(response.body).to include("email subscriptions don't carry over from year to year")
      end
    end

    context "when a bot requests a non-HTML format" do
      it "renders the HTML home page with a 200 instead of a 406" do
        get root_path, params: { format: :ics }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("email subscriptions don't carry over from year to year")
      end
    end
  end
end
