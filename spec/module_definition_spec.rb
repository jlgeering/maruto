# frozen_string_literal: true

require 'spec_helper'

require 'maruto/module_definition'

describe Maruto::ModuleDefinition do

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

		magento_root = File.expand_path('../../fixtures/magento_root', __FILE__)
		Dir.chdir(magento_root)
	end

	describe "when parsing a module definition" do

		it "will return a Hash" do
			h = Maruto::ModuleDefinition.parse_module_definition(@xml_nodes[:Mage_Core])
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
			h = Maruto::ModuleDefinition.parse_module_definition(@xml_nodes[:Mage_Core])
			h.wont_include :dependencies

			h = Maruto::ModuleDefinition.parse_module_definition(@xml_nodes[:Mage_Eav])
			h.must_include :dependencies
			h[:dependencies].size.must_equal 1
			h[:dependencies].must_include :Mage_Core

			h = Maruto::ModuleDefinition.parse_module_definition(@xml_nodes[:Mage_Customer])
			h.must_include :dependencies
			h[:dependencies].size.must_equal 2
			h[:dependencies].must_include :Mage_Dataflow
			h[:dependencies].must_include :Mage_Eav
		end

		it "will treat any module that is <active>false</active> or <active>off</active> as inactive" do
			Maruto::ModuleDefinition.parse_module_definition(Nokogiri::XML('''
				<modname>
					<active>false</active>
					<codePool>core</codePool>
				</modname>
			''').root)[:active].must_equal false
			Maruto::ModuleDefinition.parse_module_definition(Nokogiri::XML('''
				<modname>
					<active>off</active>
					<codePool>core</codePool>
				</modname>
			''').root)[:active].must_equal false
		end

		it "will warn when active is not in 'true', 'false' or 'off'" do
			h = Maruto::ModuleDefinition.parse_module_definition(Nokogiri::XML('''
				<modname>
					<active>hello</active>
					<codePool>core</codePool>
				</modname>
			''').root)
			h.must_include :active
			h.must_include :warnings
			h[:warnings].size.must_equal 1
			h[:warnings][0].must_include :message
			# any string that is not false or off => active
			# TODO empty string => inactive (check in php)
			h[:active].must_equal true

		end

		it "will warn when codePool is not in 'core', 'community' or 'local'" do
			h = Maruto::ModuleDefinition.parse_module_definition(Nokogiri::XML('''
				<modname>
					<active>true</active>
					<codePool>other</codePool>
				</modname>
			''').root)
			h.must_include :warnings
			h[:warnings].size.must_equal 1
			h[:warnings][0].must_include :message
		end
	end

	describe "when parsing a module definition file" do
		it "will return an Array of module definitions" do
			a = Maruto::ModuleDefinition.parse_module_definition_file('app/etc/modules/Mage_Api.xml')
			a.must_be_kind_of Array
			a.size.must_equal 1
			a[0].must_include :name
			a[0][:name].must_equal :Mage_Api
		end
		it "will return an Array of module definitions" do
			a = Maruto::ModuleDefinition.parse_module_definition_file('app/etc/modules/Mage_Api.xml')
			a.must_be_kind_of Array
			a.size.must_equal 1
			a[0].must_include :name
			a[0][:name].must_equal :Mage_Api
		end
		it "will add the definition file path to all warnings" do
			file = 'app/etc/modules/Bad_Example.xml'
			a = Maruto::ModuleDefinition.parse_module_definition_file(file)
			a.must_be_kind_of Array
			a.size.must_equal 1
			a[0].must_include :warnings
			a[0][:warnings].size.wont_equal 0
			a[0][:warnings].each do |w|
				w.must_include :file
				w[:file].must_equal file
			end
		end
		it "will include the relative path to the file to the module definition" do
			file = 'app/etc/modules/Mage_All.xml'
			a = Maruto::ModuleDefinition.parse_module_definition_file(file)
			a.size.must_be :>, 0
			a.each do |m|
				m.must_include :defined
				m[:defined].must_equal file
			end
		end
	end

	it "will parse all module definition files in app/etc/modules" do
		a = Maruto::ModuleDefinition.parse_all_module_definitions()
		a.must_be_kind_of Array
		a.size.must_be :>, 0
		a.each do |m|
			m.must_include :name
		end
	end

	describe "when analysing module definitions" do
		before do
			@module_a = { :name => :Mage_A,   :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
			@module_b = { :name => :Mage_B,   :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
			@module_c = { :name => :Mage_C,   :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
			@module_d = { :name => :Mage_D,   :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
			@module_e = { :name => :Short,    :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
			@module_f = { :name => :Long_A_B, :code_pool => :core, :defined => 'app/etc/modules/SomeFile.xml'}
		end
		it "will return an Array and a Hash" do
			a,h = Maruto::ModuleDefinition.analyse_module_definitions([])
			a.must_be_kind_of Array
			h.must_be_kind_of Hash
		end
		it "will not include inactive modules (in Array or Hash)" do
			parsed_module_definitions = [
				@module_a.merge({ :active => false }),
			]
			a,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			a.size.must_equal 0
			h.size.must_equal 0
		end
		it "will include active modules (in Array or Hash)" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true }),
				@module_e.merge({ :active => true }),
				@module_f.merge({ :active => true }),
			]
			_,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			h.keys.must_equal [:Mage_A, :Short, :Long_A_B]
		end
		it "will warn when a core/Mage_ module is inactive" do
			parsed_module_definitions = [
				@module_a.merge({ :active => false, :warnings => ['first warning'] }),
			]
			a,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			a.size.must_equal 0
			h.size.must_equal 0
			parsed_module_definitions[0][:warnings].size.must_equal 2
			parsed_module_definitions[0][:warnings][-1][:message].must_include 'inactive'
		end
		it "will remove missing dependencies and add a warning" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_B, :Mage_C], :warnings => ['first warning'] }),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => false }),
			]
			_,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			h[:Mage_A][:dependencies].size.must_equal 1
			h[:Mage_A][:warnings].size.must_equal 2
			h[:Mage_A][:warnings][-1][:file].must_equal @module_a[:defined]
		end
		it "will remove duplicate dependencies and add a warning" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_B, :Mage_C, :Mage_B], :warnings => ['first warning'] }),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => true }),
			]
			_,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			h[:Mage_A][:dependencies].size.must_equal 2
			h[:Mage_A][:warnings].size.must_equal 2
			h[:Mage_A][:warnings][-1][:file].must_equal @module_a[:defined]
		end
		it "will add the path to the module's config.xml" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true }),
				@module_e.merge({ :active => true }),
				@module_f.merge({ :active => true }),
			]
			_,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			h[:Mage_A][:config_path].must_equal 'app/code/core/Mage/A/etc/config.xml'
			h[:Mage_A].wont_include :warnings
			h[:Short][:config_path].must_equal 'app/code/core/Short/etc/config.xml'
			h[:Short].wont_include :warnings
			h[:Long_A_B][:config_path].must_equal 'app/code/core/Long/A/B/etc/config.xml'
			h[:Long_A_B].wont_include :warnings
		end
		it "will deactivate modules without a config.xml and add a warning" do
			parsed_module_definitions = [
				{ :name => :Hello_World, :code_pool => :core, :active => true, :defined => 'hello', :warnings => ['first warning'] },
			]
			_,_ = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			parsed_module_definitions[0][:active].must_equal false
			parsed_module_definitions[0][:warnings].size.must_equal 2
			parsed_module_definitions[0][:warnings][-1][:file].must_equal 'hello'
		end
		it "will sort the Array according to module dependencies" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true, :dependencies => [:Mage_D] }),
				@module_b.merge({ :active => true }),
				@module_c.merge({ :active => true, :dependencies => [:Mage_B, :Mage_A] }),
				@module_d.merge({ :active => true, :dependencies => [:Mage_B] }),
			]
			a,_ = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			a.map{|m| m[:name]}.must_equal [:Mage_B, :Mage_D, :Mage_A, :Mage_C]
		end
		it "will deactivate the first one, add a warning on the second one and use the second one to the Hash when 2 active modules have the same name" do
			parsed_module_definitions = [
				@module_a.merge({ :active => true }),
				@module_a.merge({ :active => true, :defined => 'b' }),
			]
			a,h = Maruto::ModuleDefinition.analyse_module_definitions(parsed_module_definitions)
			a.size.must_equal 1
			h.size.must_equal 1
			parsed_module_definitions[0][:active].must_equal false
			a[0][:active].must_equal true
			a[0][:defined].must_equal 'b'
			a[0].must_include :warnings
			a[0][:warnings][0][:file].must_equal 'b'
		end
	end

end
