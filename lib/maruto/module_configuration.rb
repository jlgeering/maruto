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

	def self.read_events_observers(xml_node)
		warnings = []
		events = {}
		[events, warnings]
	end
end
