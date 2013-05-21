require 'maruto/base'
require 'nokogiri'

require 'maruto/module_configuration/event_observers'

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

private

	def self.add_module_config_warning(m, msg)
		m[:warnings] ||= []
		m[:warnings] << { :file => m[:config_path], :message => msg }
	end

end
