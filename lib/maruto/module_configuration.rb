require 'maruto/base'
require 'nokogiri'

module Maruto::ModuleConfiguration

	def self.load(m)
		f = File.open(m[:config_path])
		doc = Nokogiri::XML(f) { |config| config.strict }
		f.close

		read_module_version(m, doc.root)
	end

	def self.read_module_version(m, xml_root)
		xml_node = xml_root.at_xpath('/config/modules')
		if xml_node.nil?
			m[:warnings] ||= []
			m[:warnings] << { :file => m[:config_path], :message => "config.xml is missing a <modules></modules> node" }
			return m
		end

		unless xml_node.at_xpath("./#{m[:name]}")
			m[:warnings] ||= []
			m[:warnings] << { :file => m[:config_path], :message => "config.xml is missing a <modules><#{m[:name]}></#{m[:name]}></modules> node" }
		end

		xml_node.xpath("./*").each do |n|
			unless n.name.to_sym == m[:name]
				m[:warnings] ||= []
				m[:warnings] << { :file => m[:config_path], :message => "config.xml contains configuration for a different module (<modules><#{n.name}></#{n.name}></modules>)" }
			end
		end

		if xml_node.at_xpath("./#{m[:name]}/version")
			m[:version] = xml_node.at_xpath("./#{m[:name]}/version").content
		end

		m
	end

	def self.parse_scoped_events_observers(base_path, xml_node)

		return [] if xml_node.nil?

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

	def self.parse_all_events_observers(base_path, xml_node)
		# TODO handle multiple global / frontend / adminhtml nodes
		h = {
			:global    => parse_scoped_events_observers(base_path + '/global',    xml_node.at_xpath('global')),
			:frontend  => parse_scoped_events_observers(base_path + '/frontend',  xml_node.at_xpath('frontend')),
			:adminhtml => parse_scoped_events_observers(base_path + '/adminhtml', xml_node.at_xpath('adminhtml')),
		}
		h.delete_if {|k,v| v.size == 0}
	end

end
