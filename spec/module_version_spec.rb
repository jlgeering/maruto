# frozen_string_literal: true

require 'spec_helper'

require 'maruto/module_configuration'

module Maruto

	describe "when parsing a module config.xml and reading the module version" do

		before do
			@module_a = { :name => :Mage_A, :active => true, :code_pool => :core, :defined => 'a', :config_path => 'app/code/core/Mage/A/etc/config.xml' }
			@module_b = { :name => :Mage_B, :active => true, :code_pool => :core, :defined => 'b', :config_path => 'app/code/core/Mage/B/etc/config.xml' }
			@module_c = { :name => :Mage_C, :active => true, :code_pool => :core, :defined => 'c', :config_path => 'app/code/core/Mage/C/etc/config.xml' }
			@module_d = { :name => :Mage_D, :active => true, :code_pool => :core, :defined => 'd', :config_path => 'app/code/core/Mage/D/etc/config.xml' }
			@xml_config_root = Nokogiri::XML('''
				<config><modules>
					<Mage_A>
						<version>0.0.1</version>
					</Mage_A>
				</modules></config>
			''').root
		end

		it "will return the an array of warnings" do
			warnings = ModuleConfiguration.parse_module_version(@module_a, @xml_config_root)
			warnings.must_be_kind_of Array
		end
		it "will add the version to the module" do
			ModuleConfiguration.parse_module_version(@module_a, @xml_config_root)
			@module_a.must_include :version
			@module_a[:version].must_equal '0.0.1'
		end
		it "will add a warning when then modules node is missing" do
			warnings = ModuleConfiguration.parse_module_version(@module_a, Nokogiri::XML('<config><a></a></config>').root)
			warnings.size.must_equal 1
			warnings[0].must_include '/config/modules'
		end
		it "will add a warning when then node with the module's name is missing" do
			warnings = ModuleConfiguration.parse_module_version(@module_a, Nokogiri::XML('<config><modules></modules></config>').root)
			warnings.size.must_equal 1
			warnings[0].must_include '/config/modules/Mage_A'
		end
		it "will add a warning when there is a node from a different module" do
			xml_config_root = Nokogiri::XML('''
				<config><modules>
					<Mage_A>
						<version>0.0.1</version>
					</Mage_A>
					<Mage_B>
						<version>0.0.1</version>
					</Mage_B>
				</modules></config>
			''').root
			warnings = ModuleConfiguration.parse_module_version(@module_a, xml_config_root)
			warnings.size.must_equal 1
			warnings[0].must_include 'Mage_B'
		end

	end
end
