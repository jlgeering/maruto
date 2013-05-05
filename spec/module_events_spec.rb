require 'spec_helper'

require 'maruto/module_configuration'

module Maruto

	describe ModuleConfiguration do


		describe "when parsing a module config.xml and reading scoped event observers" do

			before do
				@events_root = Nokogiri::XML('''
					<events>
						<first_event>
							<observers>
								<first_observer>
									<type>model</type>                    <!-- model, singleton or disabled, default is singleton (object is an alias for model) -->
									<class>Mage_A_Model_Observer</class>  <!-- observers class or class alias -->
									<method>methodName</method>           <!-- observer\'s method to be called -->
									<args></args>                         <!-- additional arguments passed to observer -->
								</first_observer>
							</observers>
						</first_event>
						<second_event>
							<observers>
								<second_observer>
									<class>Mage_B_Model_Observer</class>
									<method>doSomething</method>
								</second_observer>
								<third_observer>
									<type>object</type>
									<class>Mage_C_Model_Observer</class>
									<method>helloWorld</method>
								</third_observer>
								<disabled_observer>
									<type>disabled</type>
									<class>Mage_C_Model_Observer</class>
									<method>helloWorld</method>
								</disabled_observer>
							</observers>
						</second_event>
					</events>
				''').root.xpath('/')
			end

			it "will return a array of events" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events.must_be_kind_of Array
				events.size.must_equal 2
			end
			it "will return a array of warnings" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				warnings.must_be_kind_of Array
			end
			it "will handle a missing <events> element or a nil node" do
				node = Nokogiri::XML('''
					<hello></hello>
				''').root.xpath('/')
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', node)
				events.must_be_kind_of Array
				events.size.must_equal 0

				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', nil)
				events.must_be_kind_of Array
				events.size.must_equal 0
			end
			it "will build the path to an event" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', @events_root)
				events[0][:path].must_equal 'root/events/first_event'
			end
			it "will read the name, class, and method of an observer" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events[0][:observers][0][:name].must_equal 'first_observer'
				events[0][:observers][0][:class].must_equal 'Mage_A_Model_Observer'
				events[0][:observers][0][:method].must_equal 'methodName'
			end
			it "will read the type of an observer" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events[0][:observers][0][:type].must_equal :model
			end
			it "will handle observer declarations with default type" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events[1][:observers][0][:type].must_equal :singleton
			end
			it "will treat type 'object' as an alias to 'model'" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events[1][:observers][1][:type].must_equal :model
			end
			it "will handle disabled observers" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events[1][:observers][2][:type].must_equal :disabled
			end
			it "will handle observers with an invalid type and add a warning" do
				node = Nokogiri::XML('''
					<events>
						<first_event>
							<observers>
								<invalid_type>
									<type>something</type>
									<class>Hello_World</class>
									<method>helloWorld</method>
								</invalid_type>
							</observers>
						</first_event>
					</events>
				''').root.xpath('/')
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', node)
				events.size.must_equal 1
				events[0][:observers].size.must_equal 1
				events[0][:observers][0].must_include :type
				events[0][:observers][0][:type].must_equal :singleton
				warnings.size.must_equal 1
				warnings[0].must_include 'root/events/first_event/observers/invalid_type/type'
				warnings[0].must_include 'singleton'
				warnings[0].must_include 'something'
			end
			it "will build the path to an event observer" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', @events_root)
				events[0][:observers][0][:path].must_equal 'root/events/first_event/observers/first_observer'
			end
			it "will group observers by event" do
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('', @events_root)
				events.size.must_equal 2
				events[0].must_include :name
				events[0].must_include :observers
				events[0][:name].must_equal 'first_event'
				events[0][:observers].size.must_equal 1
				events[1][:name].must_equal 'second_event'
				events[1][:observers].size.must_equal 3
			end
			it "will handle incomplete observer declarations" do
				node = Nokogiri::XML('''
					<events>
						<first_event>
							<observers>
								<o1></o1>
								<o2>
									<class></class>
									<method></method>
								</o2>
							</observers>
						</first_event>
					</events>
				''').root.xpath('/')
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', node)
				events.size.must_equal 1
				events[0][:observers].size.must_be :>, 0
			end
			# it "will warn if an observers class is invalid" do
			# 	# TODO
			# end
			it "will handle duplicate scopes and add a warning" do
				node = Nokogiri::XML('''<config>
					<scope>
						<events>
							<e1><observers></observers></e1>
						</events>
					</scope>
					<scope>
						<events>
							<e2><observers></observers></e2>
						</events>
					</scope>
				</config>''').root
				events, warnings = ModuleConfiguration.parse_scoped_event_observers('/config/scope', node.xpath('/config/scope'))
				events.size.must_equal 2
				warnings.size.must_equal 1
				warnings[0].must_include '/config/scope'
			end
		end

		describe "when parsing all event observers" do

			before do
				@module_a = { :name => :Mage_A, :active => true, :code_pool => :core, :defined => 'a', :config_path => 'app/code/core/Mage/A/etc/config.xml' }
				@xml_root = Nokogiri::XML('''
					<config>
						<global>
							<events>
								<e1><observers><o1><type>invalid</type></o1></observers></e1>
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
					</config>
				''').root
			end

			it "will add events to the module" do
				@module_a.wont_include :events
				ModuleConfiguration.parse_all_event_observers(@module_a, @xml_root)
				@module_a.must_include :events
			end

			it "will collect warnings into an array" do
				warnings = ModuleConfiguration.parse_all_event_observers(@module_a, @xml_root)
				warnings.size.must_be :>, 0
			end


			it "will group events by scope and build the correct path" do
				@module_a.wont_include :events
				ModuleConfiguration.parse_all_event_observers(@module_a, @xml_root)
				@module_a.must_include :events

				@module_a[:events].must_be_kind_of Hash
				@module_a[:events].must_include :global
				@module_a[:events].must_include :frontend
				@module_a[:events].must_include :adminhtml

				@module_a[:events][:global].size.must_equal 1
				@module_a[:events][:global][0][:name].must_equal 'e1'
				@module_a[:events][:global][0][:path].must_include '/config/global/events'

				@module_a[:events][:frontend].size.must_equal 2
				@module_a[:events][:frontend][0][:name].must_equal 'e2'
				@module_a[:events][:frontend][0][:path].must_include '/config/frontend/events'

				@module_a[:events][:adminhtml].size.must_equal 3
				@module_a[:events][:adminhtml][0][:name].must_equal 'e4'
				@module_a[:events][:adminhtml][0][:path].must_include '/config/adminhtml/events'
			end

			it "will skip scopes without events" do
				node = Nokogiri::XML('''<config>
					<global>
						<events>
							<e1><observers><o1></o1></observers></e1>
						</events>
					</global>
				</config>''').root

				@module_a.wont_include :events
				ModuleConfiguration.parse_all_event_observers(@module_a, node)
				@module_a.must_include :events

				@module_a[:events].wont_include :frontend
				@module_a[:events].wont_include :adminhtml
			end

			it "will skip :events without events" do
				node = Nokogiri::XML('''<config>
					<global>
						<events>
						</events>
					</global>
					<frontend>
					</frontend>
				</config>''').root

				@module_a.wont_include :events
				ModuleConfiguration.parse_all_event_observers(@module_a, node)
				@module_a.wont_include :events
			end

		end

		describe "when analysing events observers" do

			# it "will warn when an event has no observers" do
			# 	xml_node_no_obs = Nokogiri::XML('''
			# 		<config><scope><events><first_event></first_event></events></scope></config>
			# 	''').root
			# 	events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', xml_node_no_obs.xpath('/config/scope'))
			# 	events.size.must_equal 0
			# 	warnings.size.must_equal 1
			# 	warnings[0].must_include 'root/events/first_event'
			# end
			# it "will warn when an event has an empty observers node" do
			# 	xml_node_empty_obs = Nokogiri::XML('''
			# 		<config><scope><events><first_event><observers></observers></first_event></events></scope></config>
			# 	''').root
			# 	events, warnings = ModuleConfiguration.parse_scoped_event_observers('root', xml_node_empty_obs.xpath('/config/scope'))
			# 	events.size.must_equal 0
			# 	warnings.size.must_equal 1
			# 	warnings[0].must_include 'root/events/first_event/observers'
			# end

		end
	end
end
