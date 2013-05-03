require 'spec_helper'

require 'maruto/module_configuration'

module Maruto

	describe ModuleConfiguration do

		before do
			@module_a = { :name => :Mage_A, :active => true, :code_pool => :core, :defined => 'a', :config_path => 'app/code/core/Mage/A/etc/config.xml' }
			@module_b = { :name => :Mage_B, :active => true, :code_pool => :core, :defined => 'b', :config_path => 'app/code/core/Mage/B/etc/config.xml' }
			@module_c = { :name => :Mage_C, :active => true, :code_pool => :core, :defined => 'c', :config_path => 'app/code/core/Mage/C/etc/config.xml' }
			@module_d = { :name => :Mage_D, :active => true, :code_pool => :core, :defined => 'd', :config_path => 'app/code/core/Mage/D/etc/config.xml' }
		end

		describe "when parsing a module config.xml" do
			describe "and reading the module version" do
				before do
					@xml_config_root = Nokogiri::XML('''
						<config><modules>
							<Mage_A>
								<version>0.0.1</version>
							</Mage_A>
						</modules></config>
					''').root
				end
				it "will return the module definition hash" do
					m = ModuleConfiguration.read_module_version(@module_a, @xml_config_root)
					m.must_be_kind_of Hash
					m.must_equal @module_a
				end
				it "will add the version to the hash" do
					m = ModuleConfiguration.read_module_version(@module_a, @xml_config_root)
					m.must_include :version
					m[:version].must_equal '0.0.1'
				end
				it "will add a warning when then modules node is missing" do
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, Nokogiri::XML('<config><a></a></config>').root)
					m[:warnings].size.must_equal 2
					m[:warnings][-1][:message].must_include '<modules'
				end
				it "will add a warning when then node with the module's name is missing" do
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, Nokogiri::XML('<config><modules></modules></config>').root)
					m[:warnings].size.must_equal 2
					m[:warnings][-1][:message].must_include '<modules'
					m[:warnings][-1][:message].must_include '<Mage_A'
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
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, xml_config_root)
					m[:warnings].size.must_equal 2
					m[:warnings][-1][:message].must_include 'Mage_B'
				end
			end
		end
	end
end
