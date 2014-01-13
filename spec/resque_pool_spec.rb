require 'spec_helper'

RSpec.configure do |config|
  config.after {
    Object.send(:remove_const, :RAILS_ENV) if defined? RAILS_ENV
    ENV.delete 'RACK_ENV'
    ENV.delete 'RAILS_ENV'
    ENV.delete 'RESQUE_ENV'
    ENV.delete 'RESQUE_POOL_CONFIG'
  }
end

describe Resque::Pool, "when loading a simple pool configuration" do
  let(:config) do
    { 'foo' => 1, 'bar' => 2, 'foo,bar' => 3, 'bar,foo' => 4, }
  end

  let(:pool) { Resque::Pool.instance }
  before { pool.init_config(config) }
  subject { pool }

  context "when ENV['RACK_ENV'] is set" do
    before { ENV['RACK_ENV'] = 'development' }

    it "should load the values from the Hash" do
      subject.config["foo"].should == 1
      subject.config["bar"].should == 2
      subject.config["foo,bar"].should == 3
      subject.config["bar,foo"].should == 4
    end
  end

end

describe Resque::Pool, "when loading the pool configuration from a Hash" do
  let(:config) do
    {
      'foo' => 8,
      'test'        => { 'bar' => 10, 'foo,bar' => 12 },
      'development' => { 'baz' => 14, 'foo,bar' => 16 },
    }
  end

  let(:pool) { Resque::Pool.instance }
  context "when RAILS_ENV is set" do
    before do
      RAILS_ENV = "test"
      pool.init_config(config)
    end

    subject { pool }

    it "should load the default values from the Hash" do
      subject.config["foo"].should == 8
    end

    it "should merge the values for the correct RAILS_ENV" do
      subject.config["bar"].should == 10
      subject.config["foo,bar"].should == 12
    end

    it "should not load the values for the other environments" do
      subject.config["foo,bar"].should == 12
      subject.config["baz"].should be_nil
    end

  end

  context "when Rails.env is set" do
    before(:each) do
      module Rails; end
      Rails.stub(:env).and_return('test')
      pool.init_config(config)
    end

    subject { pool }

    it "should load the default values from the Hash" do
      subject.config["foo"].should == 8
    end

    it "should merge the values for the correct RAILS_ENV" do
      subject.config["bar"].should == 10
      subject.config["foo,bar"].should == 12
    end

    it "should not load the values for the other environments" do
      subject.config["foo,bar"].should == 12
      subject.config["baz"].should be_nil
    end

    after(:all) { Object.send(:remove_const, :Rails) }
  end


  context "when ENV['RESQUE_ENV'] is set" do
    before do
      ENV['RESQUE_ENV'] = 'development'
      pool.init_config(config)
    end

    subject { pool }

    it "should load the config for that environment" do
      subject.config["foo"].should == 8
      subject.config["foo,bar"].should == 16
      subject.config["baz"].should == 14
      subject.config["bar"].should be_nil
    end
  end

  context "when there is no environment" do
    before { pool.init_config(config) }
    subject { pool }

    it "should load the default values only" do
      subject.config["foo"].should == 8
      subject.config["bar"].should be_nil
      subject.config["foo,bar"].should be_nil
      subject.config["baz"].should be_nil
    end
  end

end

describe Resque::Pool, "given no configuration" do
  let(:pool) { Resque::Pool.instance }
  before { pool.init_config({}) }
  subject { pool }

  it "should have no worker types" do
    subject.config.should == {}
  end
end

describe Resque::Pool, "when loading the pool configuration from a file" do
  let(:pool) { Resque::Pool.instance }

  context "when RAILS_ENV is set" do
    before do
      RAILS_ENV = "test"
      pool.init_config("spec/resque-pool.yml")
    end

    subject { pool }

    it "should load the default YAML" do
      subject.config["foo"].should == 1
    end

    it "should merge the YAML for the correct RAILS_ENV" do
      subject.config["bar"].should == 5
      subject.config["foo,bar"].should == 3
    end

    it "should not load the YAML for the other environments" do
      subject.config["foo"].should == 1
      subject.config["bar"].should == 5
      subject.config["foo,bar"].should == 3
      subject.config["baz"].should be_nil
    end

  end

  context "when ENV['RACK_ENV'] is set" do
    before do
      ENV['RACK_ENV'] = 'development'
      pool.init_config("spec/resque-pool.yml")
    end

    subject { pool }

    it "should load the config for that environment" do
      subject.config["foo"].should == 1
      subject.config["foo,bar"].should == 4
      subject.config["baz"].should == 23
      subject.config["bar"].should be_nil
    end
  end

  context "when there is no environment" do
    before { pool.init_config("spec/resque-pool.yml") }
    subject { pool }

    it "should load the default values only" do
      subject.config["foo"].should == 1
      subject.config["bar"].should be_nil
      subject.config["foo,bar"].should be_nil
      subject.config["baz"].should be_nil
    end
  end

  context "when a custom file is specified" do
    let(:pool) { Resque::Pool.instance }

    before do
      ENV["RESQUE_POOL_CONFIG"] = 'spec/resque-pool-custom.yml.erb'
      pool.init_config Resque::Pool.choose_config_file
    end

    it "should find the right file, and parse the ERB" do
      pool.config["foo"].should == 2
    end
  end
end

describe Resque::Pool, "given after_prefork hook" do
  let(:pool) { Resque::Pool.instance }
  subject { pool }

  context "with a single hook" do
    before { Resque::Pool.after_prefork { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!
      @called.should == true
    end
  end

  context "with a single hook by attribute writer" do
    before { Resque::Pool.after_prefork = Proc.new { @called = true } }

    it "should call prefork" do
      subject.call_after_prefork!
      @called.should == true
    end
  end

  context "with multiple hooks" do
    before {
      Resque::Pool.after_prefork { @called_first = true }
      Resque::Pool.after_prefork { @called_second = true }
    }

    it "should call both" do
      subject.call_after_prefork!
      @called_first.should == true
      @called_second.should == true
    end
  end
end
