# frozen_string_literal: true

RSpec.describe "Running the CLI" do
  it "runs" do
    expect(system("./exe/radius-cli 2>&1 1>/dev/null")).to be_truthy
  end
end
