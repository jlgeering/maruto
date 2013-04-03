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

	describe "when analysing module definitions" do
		before do
			@module_a = { :name => :Mage_A, :code_pool => :core, :defined => 'a'}
			@module_b = { :name => :Mage_B, :code_pool => :core, :defined => 'b'}
			@module_c = { :name => :Mage_C, :code_pool => :core, :defined => 'c'}
			@module_d = { :name => :Mage_D, :code_pool => :core, :defined => 'd'}
		end
		it "will return an Array and a Hash" do
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, [])
			a.must_be_kind_of Array
			h.must_be_kind_of Hash
		end
		it "will not include inactive modules (in Array or Hash)" do
			parsed_module_definitions = [
				@module_a.merge({ :active => false}),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			a.size.must_equal 0
			h.size.must_equal 0
		end
		it "will remove missing dependencies and add a warning" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_B, :Mage_C], :warnings => ['first warning']}),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => false }),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			h[:Mage_A][:dependencies].size.must_equal 1
			h[:Mage_A][:warnings].size.must_equal 2
		end
		it "will remove duplicate dependencies and add a warning" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_B, :Mage_C, :Mage_B], :warnings => ['first warning']}),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => true }),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			h[:Mage_A][:dependencies].size.must_equal 2
			h[:Mage_A][:warnings].size.must_equal 2
		end
		it "will deactivate modules with an invalid name and add a warning" do
			parsed_module_definitions = [
				{ :name => :a, :active => true, :defined => 'a', :warnings => ['first warning'] },
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			parsed_module_definitions[0][:active].must_equal false
			parsed_module_definitions[0][:warnings].size.must_equal 2
			parsed_module_definitions[0][:warnings][-1].must_include "invalid module name"
		end
		it "will add the path to the module's config.xml" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true }),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			h[:Mage_A][:config_path].must_equal 'app/code/core/Mage/A/etc/config.xml'
			h[:Mage_A].wont_include :warnings
		end
		it "will deactivate modules without a config.xml and add a warning" do
			parsed_module_definitions = [
				{ :name => :Mage_E, :code_pool => :core, :active => true, :defined => 'e', :warnings => ['first warning'] },
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			parsed_module_definitions[0][:active].must_equal false
			parsed_module_definitions[0][:warnings].size.must_equal 2
		end
		it "will sort the Array according to module dependencies" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_D] }),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => true, :dependencies => [:Mage_B, :Mage_A] }),
				@module_d.merge({ :active => true, :dependencies => [:Mage_B] }),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			a.map{|m| m[:name]}.must_equal [:Mage_B, :Mage_D, :Mage_A, :Mage_C]
		end
		it "will deactivate the first one, add a warning on the second one and use the second one to the Hash when 2 active modules have the same name" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true }),
				@module_a.merge({ :active => true, :defined => 'b' }),
			]
			a,h = Maruto::ConfigParser.analyse_module_definitions(@magento_root, parsed_module_definitions)
			a.size.must_equal 1
			h.size.must_equal 1
			parsed_module_definitions[0][:active].must_equal false
			a[0][:active].must_equal true
			a[0][:defined].must_equal 'b'
			a[0].must_include :warnings
		end
	end

end

