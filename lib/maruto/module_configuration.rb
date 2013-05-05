require 'maruto/base'
require 'nokogiri'

module Maruto::ModuleConfiguration

	def self.load(m)
		f = File.open(m[:config_path])
		doc = Nokogiri::XML(f) { |config| config.strict }
		f.close

		read_module_version(m, doc.root)
		read_module_version(m, doc.root)
	end

	def self.read_module_version(m, xml_root)
		xml_node = xml_root.at_xpath('/config/modules')
		if xml_node.nil?
			m[:warnings] ||= []
			m[:warnings] << { :file => m[:config_path], :message => "config.xml is missing a /config/modules node" }
			return m
		end

		unless xml_node.at_xpath("./#{m[:name]}")
			m[:warnings] ||= []
			m[:warnings] << { :file => m[:config_path], :message => "config.xml is missing a /config/modules/#{m[:name]} node" }
		end

		xml_node.xpath("./*").each do |n|
			unless n.name.to_sym == m[:name]
				m[:warnings] ||= []
				m[:warnings] << { :file => m[:config_path], :message => "config.xml contains configuration for a different module (/config/modules/#{n.name})" }
			end
		end

		if xml_node.at_xpath("./#{m[:name]}/version")
			m[:version] = xml_node.at_xpath("./#{m[:name]}/version").content
		end

		m
	end

	def self.parse_scoped_events_observers(base_path, xml_node)

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
				observer[:type]   = o.at_xpath('type').content
				observer[:class]  = o.at_xpath('class').content
				observer[:method] = o.at_xpath('method').content

				event[:observers] << observer
			end

			events << event
		end

		return events, warnings
	end

	def self.parse_all_events_observers(xml_node)
		scopes = [:global, :frontend, :adminhtml]
		events = {}
		scopes.each do |scope|
			e,w = parse_scoped_events_observers("/config/#{scope}",    xml_node.xpath("/config/#{scope}"))
			events[scope] = e if e.size > 0
		end
		events
	end

end
