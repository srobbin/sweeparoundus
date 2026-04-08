require "rails_helper"

RSpec.describe "Home", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /" do
    it "renders the home page" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    context "in December (sweeping done for year)" do
      it "shows the off-season message" do
        travel_to Date.new(2026, 12, 15) do
          get root_path

          expect(response.body).to include("SWEEP YOU NEXT YEAR")
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

        expect(response.body).to include("alert subscriptions do not carry over from year to year")
      end
    end
  end
end
