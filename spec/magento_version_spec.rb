require 'spec_helper'

require 'maruto/magento_version'

module Maruto

	describe "when reading the magento version" do

		before do
			@magento_root_1_0 = File.expand_path('../../fixtures/magento_1.0', __FILE__)
		end

		it "will return an array" do
			Dir.chdir(@magento_root_1_0) do
				version = MagentoVersion.read_magento_version()
				version.must_be_kind_of Array
			end
		end
		it "will read version 1.0" do
			Dir.chdir(@magento_root_1_0) do
				version = MagentoVersion.read_magento_version()
				version.size.must_equal 2
				version[0].must_equal 1
				version[1].must_equal 0
			end
		end

	end
end
