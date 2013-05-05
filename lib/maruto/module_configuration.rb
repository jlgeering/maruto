require 'maruto/base'
require 'nokogiri'

module Maruto::ModuleConfiguration

	def self.parse_module_configuration(m)
		f = File.open(m[:config_path])
		xml_root = Nokogiri::XML(f) { |config| config.strict }.root
		f.close

		version_warnings = parse_module_version(m, xml_root)
		event_warnings   = parse_all_events_observers(m, xml_root)

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
		scopes = [:global, :frontend, :adminhtml]
		events = {}
		warnings = []
		scopes.each do |scope|
			e, w = parse_scoped_event_observers("/config/#{scope}",    xml_node.xpath("/config/#{scope}"))

			events[scope] = e if e.size > 0
			warnings.concat w
		end
		m[:events] = events if events.keys.size > 0
		return warnings
	end

	def self.analyse_module_configuration()
	end
end
