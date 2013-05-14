require 'maruto/base'
require 'nokogiri'

module Maruto::ModuleConfiguration

	def self.parse_module_configuration(m)
		f = File.open(m[:config_path])
		xml_root = Nokogiri::XML(f) { |config| config.strict }.root
		f.close

		version_warnings = parse_module_version(m, xml_root)
		event_warnings   = parse_all_event_observers(m, xml_root)

		config_warnings = version_warnings + event_warnings

		all_module_warnings = m[:warnings] || []
		all_module_warnings.concat(config_warnings.map { |msg| { :file => m[:config_path], :message => msg } })

		m[:warnings] = all_module_warnings unless all_module_warnings.size == 0

		m
	end

	def self.parse_module_version(m, xml_root)
		xml_node = xml_root.at_xpath('/config/modules')

		if xml_node.nil?
			return ["config.xml is missing a /config/modules node"]
		end

		warnings = []

		unless xml_node.at_xpath("./#{m[:name]}")
			warnings << "config.xml is missing a /config/modules/#{m[:name]} node"
		end

		xml_node.xpath("./*").each do |n|
			unless n.name.to_sym == m[:name]
				warnings << "config.xml contains configuration for a different module (/config/modules/#{n.name})"
			end
		end

		m[:version] = xml_node.at_xpath("./#{m[:name]}/version").content unless xml_node.at_xpath("./#{m[:name]}/version").nil?

		warnings
	end

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
						if events[event_name].include? observer_name
							add_module_config_warning(m, "event_observer:#{area}/#{event_name}/#{observer_name} - defined in #{events[event_name][observer_name][:module]} and redefined in #{m[:name]}")
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

private

	def self.add_module_config_warning(m, msg)
		m[:warnings] ||= []
		m[:warnings] << { :file => m[:config_path], :message => msg }
	end

end
