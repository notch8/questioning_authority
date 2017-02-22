require 'spec_helper'

describe Qa::Authorities do
  let(:name)      { 'MyAuth' }
  let(:authority) { Class.new(Qa::Authorities::Base) }

  describe '.authorities' do
    it 'is a list of authorities' do
      expect(described_class.authorities).to respond_to :to_ary
    end
  end

  describe '.class_for' do
    before { described_class.register(name: name, klass: authority) }

    it 'retrieves a registered authority' do
      expect(described_class.class_for(name: name)).to eql authority
    end

    it 'raises an error for an unregistered authority' do
      expect { described_class.class_for(name: 'fake') }
        .to raise_error NameError, /fake/
    end
  end

  describe '.register' do
    it 'registers an authority' do
      expect { described_class.register(name: name, klass: authority) }
        .to change { described_class.authorities }
        .to include authority
    end
  end
end
