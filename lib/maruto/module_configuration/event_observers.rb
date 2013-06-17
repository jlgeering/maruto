module Maruto::ModuleConfiguration

	def self.parse_scoped_event_observers(base_path, xml_node)

		return [],[] if xml_node.nil?

		events   = []
		warnings = []

		if xml_node.size > 1
			warnings << "duplicate element in config.xml (#{base_path})"
		end

		xml_node.xpath('events/*').each do |e|
			event = {
				:name => e.name,
				:path => base_path + '/events/' + e.name,
				:observers => [],
			}

			e.xpath('observers/*').each do |o|
				observer = {
					:name => o.name,
					:path => event[:path] + '/observers/' + o.name,
				}
				type              = o.at_xpath('type').content   unless o.at_xpath('type').nil?
				observer[:class]  = o.at_xpath('class').content  unless o.at_xpath('class').nil?
				observer[:method] = o.at_xpath('method').content unless o.at_xpath('method').nil?

				# see Mage_Core_Model_App::dispatchEvent
				if type.nil?
					# default is singleton
					observer[:type] = :singleton
				elsif type == 'object'
					# object is an alias for model
					observer[:type] = :model
					warnings << "#{observer[:path]}/type 'object' is an alias for 'model'"
				elsif /^(disabled|model|singleton)$/ =~ type
					observer[:type] = type.to_sym
				else
					# everything else => default (with warning)
					observer[:type] = :singleton
					warnings << "#{observer[:path]}/type replaced with 'singleton', was '#{type}' (possible values: 'disabled', 'model', 'singleton', or nothing)"
				end

				event[:observers] << observer
			end

			events << event
		end

		return events, warnings
	end

	def self.parse_all_event_observers(m, xml_node)
		areas = [:global, :frontend, :adminhtml, :crontab]
		events = {}
		warnings = []
		areas.each do |area|
			e, w = parse_scoped_event_observers("/config/#{area}",    xml_node.xpath("/config/#{area}"))

			events[area] = e if e.size > 0
			warnings.concat w
		end
		m[:events] = events if events.keys.size > 0

		warnings << "the 'admin' area should not contain events (/config/admin/events)" unless xml_node.at_xpath("/config/admin/events").nil?

		return warnings
	end

	def self.collect_scoped_event_observers(area, sorted_modules)
		events = Hash.new

		sorted_modules.each do |m|
			if m.include? :events and m[:events].include? area then
				m[:events][area].each do |event|
					event_name = event[:name]
					events[event_name] ||= Hash.new
					event[:observers].each do |observer|
						observer_name = observer[:name]
						if events[event_name].include? observer_name then
							if observer[:type] != :disabled
								add_module_config_warning(m, "event_observer:#{area}/#{event_name}/#{observer_name} - defined in module:#{events[event_name][observer_name][:module]} and redefined in module:#{m[:name]} (use type: disabled instead)")
							end
							unless m.include? :dependencies and m[:dependencies].include? events[event_name][observer_name][:module]
								add_module_config_warning(m, "module:#{m[:name]} should have a dependency on module:#{events[event_name][observer_name][:module]} because of event_observer:#{area}/#{event_name}/#{observer_name}")
							end
						else
							if observer[:type] == :disabled
								add_module_config_warning(m, "event_observer:#{area}/#{event_name}/#{observer_name} - cannot disable an inexistant event observer")
							end
						end
						events[event_name][observer_name] = observer
						events[event_name][observer_name][:module] = m[:name]
					end
				end
			end
		end

		events
	end

	def self.collect_event_observers(sorted_modules)
		areas = [:global, :frontend, :adminhtml, :crontab]
		events = {}

		areas.each do |area|
			events[area] = collect_scoped_event_observers(area, sorted_modules)
		end

		events
	end

end
