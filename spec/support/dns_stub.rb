# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    dns = instance_double(Resolv::DNS)
    allow(Resolv::DNS).to receive(:open).and_yield(dns)
    allow(dns).to receive(:timeouts=)
    allow(dns).to receive(:getresources).and_return([ instance_double(Resolv::DNS::Resource::IN::MX) ])
  end
end
