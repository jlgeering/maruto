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
					@xml_node = Nokogiri::XML('''
						<events>
							<first_event>
								<observers>
									<first_observer>
										<type>model</type>                    <!-- model, object or singleton -->
										<class>Mage_A_Model_Observer</class>  <!-- observers class or class alias -->
										<method>methodName</method>           <!-- observer\'s method to be called -->
										<args></args>                         <!-- additional arguments passed to observer -->
									</first_observer>
								</observers>
							</first_event>
							<second_event>
								<observers>
									<second_observer>
										<type>object</type>
										<class>Mage_B_Model_Observer</class>
										<method>doSomething</method>
									</second_observer>
									<third_observer>
										<type>singleton</type>
										<class>Mage_C_Model_Observer</class>
										<method>helloWorld</method>
									</third_observer>
								</observers>
							</second_event>
						</events>
					''').root.at_xpath('/')
				end
				it "will return a array of events" do
					e = ModuleConfiguration.parse_scoped_events_observers('', @xml_node)
					e.must_be_kind_of Array
					e.size.must_equal 2
				end
				it "will handle a missing <events> element or a nil node" do
					node = Nokogiri::XML('''
						<hello></hello>
					''').root.at_xpath('/')
					e = ModuleConfiguration.parse_scoped_events_observers('', node)
					e.must_be_kind_of Array
					e.size.must_equal 0

					e = ModuleConfiguration.parse_scoped_events_observers('', nil)
					e.must_be_kind_of Array
					e.size.must_equal 0
				end
				it "will build the path to an event" do
					e = ModuleConfiguration.parse_scoped_events_observers('root', @xml_node)
					e[0][:path].must_equal 'root/events/first_event'
				end
				it "will read the name type class and method of an observer" do
					e = ModuleConfiguration.parse_scoped_events_observers('', @xml_node)
					e[0][:observers][0][:name].must_equal 'first_observer'
					e[0][:observers][0][:type].must_equal 'model'
					e[0][:observers][0][:class].must_equal 'Mage_A_Model_Observer'
					e[0][:observers][0][:method].must_equal 'methodName'
				end
				it "will build the path to an event observer" do
					e = ModuleConfiguration.parse_scoped_events_observers('root', @xml_node)
					e[0][:observers][0][:path].must_equal 'root/events/first_event/observers/first_observer'
				end
				it "will group observers by events" do
					e = ModuleConfiguration.parse_scoped_events_observers('', @xml_node)
					e.size.must_equal 2
					e[0].must_include :name
					e[0].must_include :observers
					e[0][:name].must_equal 'first_event'
					e[0][:observers].size.must_equal 1
					e[1][:name].must_equal 'second_event'
					e[1][:observers].size.must_equal 2
				end
			end

			it "will group events by scope and build the correct path" do
				node = Nokogiri::XML('''<config>
					<global>
						<events>
							<e1><observers></observers></e1>
						</events>
					</global>
					<frontend>
						<events>
							<e2><observers></observers></e2>
							<e3></e3>
						</events>
					</frontend>
					<adminhtml>
						<events>
							<e4></e4>
							<e5></e5>
							<e6></e6>
						</events>
					</adminhtml>
				</config>''').root

				e = ModuleConfiguration.parse_all_events_observers('root', node)

				e.must_be_kind_of Hash
				e.must_include :global
				e.must_include :frontend
				e.must_include :adminhtml

				e[:global].size.must_equal 1
				e[:global][0][:name].must_equal 'e1'
				e[:global][0][:path].must_include 'root/global/events'

				e[:frontend].size.must_equal 2
				e[:frontend][0][:name].must_equal 'e2'
				e[:frontend][0][:path].must_include 'root/frontend/events'

				e[:adminhtml].size.must_equal 3
				e[:adminhtml][0][:name].must_equal 'e4'
				e[:adminhtml][0][:path].must_include 'root/adminhtml/events'
			end
			it "will skip scopes without events" do
				node = Nokogiri::XML('''
					<global>
						<events>
						</events>
					</global>
					<frontend>
					</frontend>
				''').root
				e = ModuleConfiguration.parse_all_events_observers('', node)
				e.must_be_kind_of Hash
				e.wont_include :global
				e.wont_include :frontend
				e.wont_include :adminhtml
			end
		end
	end
end
