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
	end

	describe "when parsing a module definition" do

		it "will return a Hash" do
			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Core])
			h.must_be_kind_of Hash
			h.must_include :Mage_Core
			h[:Mage_Core].must_include :code_pool
			h[:Mage_Core].must_include :active
			h[:Mage_Core].wont_include :dependencies
			h[:Mage_Core].wont_include :warnings
			h[:Mage_Core][:code_pool].must_equal :core
			h[:Mage_Core][:active].must_equal true
		end

		it "will find dependencies" do
			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Eav])[:Mage_Eav]
			h.must_include :dependencies
			h[:dependencies].size.must_equal 1
			h[:dependencies].must_include :Mage_Core

			h = Maruto::ConfigParser.parse_module_definition(@xml_nodes[:Mage_Customer])[:Mage_Customer]
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
			''').root)[:modname][:active].must_equal false
			Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>off</active>
						<codePool>core</codePool>
				</modname>
			''').root)[:modname][:active].must_equal false
		end

		it "will warn when active is not in 'true', 'false' or 'off'" do
			h = Maruto::ConfigParser.parse_module_definition(Nokogiri::XML('''
				<modname>
						<active>hello</active>
						<codePool>core</codePool>
				</modname>
			''').root)[:modname]
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
			''').root)[:modname]
			h.must_include :warnings
		end
	end
end

