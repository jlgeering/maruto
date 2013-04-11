require 'maruto/base'
require 'nokogiri'

module Maruto::ModuleConfiguration

	def self.read_module_version(m, xml_node)
		if xml_node.nil?
			m[:warnings] ||= []
			m[:warnings] << "module:#{m[:name]} - config.xml is missing a <modules></modules> node (in '#{m[:config_path]}')"
			return m
		end

		unless xml_node.at_xpath("./#{m[:name]}")
			m[:warnings] ||= []
			m[:warnings] << "module:#{m[:name]} - config.xml is missing a <modules><#{m[:name]}></#{m[:name]}></modules> node (in '#{m[:config_path]}')"
		end

		xml_node.xpath("./*").each do |n|
			unless n.name.to_sym == m[:name]
				m[:warnings] ||= []
				m[:warnings] << "module:#{m[:name]} - config.xml contains configuration for a different module (<modules><#{n.name}></#{n.name}></modules> in '#{m[:config_path]}')"
			end
		end

		if xml_node.at_xpath("./#{m[:name]}/version")
			m[:version] = xml_node.at_xpath("./#{m[:name]}/version").content
		end

		m
	end

	def self.parse_events_observers(base_path, xml_node)
		events = []

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

		events
	end

end
