require 'maruto/base'
require 'nokogiri'

module Maruto::ConfigParser

	def self.parse_module_definition(xml_node)
		name = xml_node.name.to_sym

		config = {
			:active       => !(/^(false|off)$/ =~ xml_node.at_xpath('active').content),
			:code_pool    => xml_node.at_xpath('codePool').content.to_sym,
		}

		deps = xml_node.xpath('depends/*').map { |e| e.name.to_sym }
		config[:dependencies] = deps if deps.size > 0

		unless /^(true|false|off)$/ =~ xml_node.at_xpath('active').content then
			config[:warnings] = ["value for active element should be in ['true','false','off'] (element: #{xml_node.at_xpath('active')})"]
		end

		unless /^(core|community|local)$/ =~ xml_node.at_xpath('codePool').content then
			config[:warnings] = ["value for codePool element should be in ['core','community','local'] (element: #{xml_node.at_xpath('codePool')})"]
		end

		{ name => config }
	end

end
