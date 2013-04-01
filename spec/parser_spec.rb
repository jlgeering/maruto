require 'spec_helper'

require 'maruto/config_parser'

describe "Config Parser" do

	before do
		@xml_nodes = {}
		@xml_nodes[:Mage_Core] = Nokogiri::XML('''
			<Mage_Core>
				<active>true</active>
				<codePool>core</codePool>
			</Mage_Core>
		''').root
		@xml_nodes[:Mage_Customer] = Nokogiri::XML('''
			<Mage_Customer>
				<active>true</active>
				<codePool>core</codePool>
				<depends>
					<Mage_Eav/>
					<Mage_Dataflow/>
				</depends>
			</Mage_Customer>
		''').root
		@xml_nodes[:Mage_Dataflow] = Nokogiri::XML('''
			<Mage_Dataflow>
				<active>true</active>
				<codePool>core</codePool>
				<depends>
					<Mage_Core/>
				</depends>
			</Mage_Dataflow>
		''').root
		@xml_nodes[:Mage_Eav] = Nokogiri::XML('''
			<Mage_Eav>
				<active>true</active>
				<codePool>core</codePool>
				<depends>
					<Mage_Core/>
				</depends>
			</Mage_Eav>
		''').root

		@magento_root = File.expand_path('../../fixtures/magento_root', __FILE__)
	end

	describe "when parsing a module definition" do

		it "will return a Hash" do
			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Core])
			h.must_be_kind_of Hash
			h.must_include :name
			h.must_include :code_pool
			h.must_include :active
			h.wont_include :dependencies
			h.wont_include :warnings
			h[:name].must_equal :Mage_Core
			h[:code_pool].must_equal :core
			h[:active].must_equal true
		end

		it "will find dependencies" do
			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Eav])
			h.must_include :dependencies
			h[:dependencies].size.must_equal 1
			h[:dependencies].must_include :Mage_Core

			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Customer])
			h.must_include :dependencies
			h[:dependencies].size.must_equal 2
			h[:dependencies].must_include :Mage_Dataflow
			h[:dependencies].must_include :Mage_Eav
		end

		it "will treat any module that is <active>false</active> or <active>off</active> as inactive" do
			Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>false</active>
						<codePool>core</codePool>
				</modname>
			''').root)[:active].must_equal false
			Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>off</active>
						<codePool>core</codePool>
				</modname>
			''').root)[:active].must_equal false
		end

		it "will warn when active is not in 'true', 'false' or 'off'" do
			h = Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>hello</active>
						<codePool>core</codePool>
				</modname>
			''').root)
			h.must_include :active
			h.must_include :warnings
			# any string that is not false or off => active
			# TODO empty string => inactive (check in php)
			h[:active].must_equal true

		end

		it "will warn when codePool is not in 'core', 'community' or 'local'" do
			h = Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>true</active>
						<codePool>other</codePool>
				</modname>
			''').root)
			h.must_include :warnings
		end
	end

	describe "when parsing a module definition file" do
		it "will return an Array of module definitions" do
			Dir.chdir(@magento_root) do
				a = Maruto::ConfigParser.parse_module_definition_file('app/etc/modules/Mage_Api.xml')
				a.must_be_kind_of Array
				a.size.must_equal 1
				a[0].must_include :name
				a[0][:name].must_equal :Mage_Api
			end
		end
		it "will include the relative path to the file to the module definition" do
			Dir.chdir(@magento_root) do
				file = 'app/etc/modules/Mage_All.xml'
				a = Maruto::ConfigParser.parse_module_definition_file(file)
				a.size.must_be :>, 0
				a.each do |m|
					m.must_include :defined
					m[:defined].must_equal file
				end
			end
		end
	end

	it "will parse all module definition files in app/etc/modules" do
		a = Maruto::ConfigParser.parse_all_module_definitions(@magento_root)
		a.must_be_kind_of Array
		a.size.must_be :>, 0
		a.each do |m|
			m.must_include :name
		end
	end

end

