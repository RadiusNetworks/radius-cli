# frozen_string_literal: true

RSpec.describe "Running the CLI" do
  it "runs" do
    expect(system("./exe/radius-cli", err: IO::NULL, out: IO::NULL)).to be_truthy
  end
end
