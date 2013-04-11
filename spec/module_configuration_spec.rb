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
					@xml_module_version = Nokogiri::XML('''
						<modules>
							<Mage_A>
								<version>0.0.1</version>
							</Mage_A>
						</modules>
					''').root.at_xpath('/modules')
				end
				it "will return the module definition hash" do
					m = ModuleConfiguration.read_module_version(@module_a, @xml_module_version)
					m.must_be_kind_of Hash
					m.must_equal @module_a
				end
				it "will add the version to the hash" do
					m = ModuleConfiguration.read_module_version(@module_a, @xml_module_version)
					m.must_include :version
					m[:version].must_equal '0.0.1'
				end
				it "will add a warning when then modules node is missing" do
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, nil)
					m[:warnings].size.must_equal 2
					m[:warnings][-1].must_include '<modules'
				end
				it "will add a warning when then node with the module's name is missing" do
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, Nokogiri::XML('<modules></modules>').root.at_xpath('/modules'))
					m[:warnings].size.must_equal 2
					m[:warnings][-1].must_include '<modules'
					m[:warnings][-1].must_include '<Mage_A'
				end
				it "will add a warning when there is a node from a different module" do
					@xml_node = Nokogiri::XML('''
						<modules>
							<Mage_A>
								<version>0.0.1</version>
							</Mage_A>
							<Mage_B>
								<version>0.0.1</version>
							</Mage_B>
						</modules>
					''').root.at_xpath('/modules')
					w = @module_a.merge({ :warnings => ['first warning'] })
					m = ModuleConfiguration.read_module_version(w, @xml_node)
					m[:warnings].size.must_equal 2
					m[:warnings][-1].must_include 'Mage_B'
				end
			end
			describe "and reading events observers" do
				before do
					@xml_node_1 = Nokogiri::XML('''
						<events>
							<first_event>
								<observers>
									<first_observer>
										<type>singleton</type>
										<class>Mage_A_Model_Observer</class>
										<method>methodName</method>
									</first_observer>
								</observers>
							</first_event>
						</events>
					''').root.at_xpath('/events')
					@xml_node_2 = Nokogiri::XML('''
						<events>
							<first_event>
								<observers>
									<first_observer>
										<type>singleton</type>
										<class>Mage_A_Model_Observer</class>
										<method>methodName</method>
									</first_observer>
								</observers>
							</first_event>
							<second_event>
								<observers>
									<second_observer>
										<type>singleton</type>
										<class>Mage_A_Model_Observer</class>
										<method>methodName</method>
									</second_observer>
									<third_observer>
										<type>singleton</type>
										<class>Mage_A_Model_Observer</class>
										<method>methodName</method>
									</third_observer>
								</observers>
							</second_event>
						</events>
					''').root.at_xpath('/events')
				end
				it "will return a hash and an array" do
					e,w = ModuleConfiguration.read_events_observers(@xml_node_1)
					e.must_be_kind_of Hash
					w.must_be_kind_of Array
				end
			end
		end
	end
end
