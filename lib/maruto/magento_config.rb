require 'tsort'

module Maruto
	class MagentoConfig
		include TSort

		def initialize(magento_root)

			@modules = {}
			@global_events_observers = {}
			@warnings = []

			Dir.chdir(magento_root) do

				# load module definitions
				Dir.glob('app/etc/modules/*.xml') do |file|
					f = File.open(file)
					doc = Nokogiri::XML(f) { |config| config.strict }
					f.close

					doc.xpath('//modules/*').each do |node|
						load_module_definition(file, node)
					end
				end

				# sort modules dependency graph, then load their config
				modules().each do |mm_name, mm_config|
					if mm_config[:active] then
						# check dependencies
						mm_config[:dependencies].each do |dep|
							@warnings << "module:#{mm_name} - missing dependency (#{dep})" unless is_active_module?(dep)
						end

						# puts mm_name
						# puts mm_config

						parts = mm_name.split('_')
						abort "module:#{mm_name} - unrecognized module name format" unless parts.size == 2
						config_path = "app/code/#{mm_config[:code_pool]}/#{parts[0]}/#{parts[1]}/etc/config.xml"

						if !File.exists?(config_path)
							@warnings << "module:#{mm_name} is defined (#{mm_config[:defined]}) but does not exists (#{config_path})"
							next
						end

						f = File.open(config_path)
						doc = Nokogiri::XML(f) { |config| config.strict }
						f.close

						mm_config[:version] = doc.at_xpath("/config/modules/#{mm_name}/version").content if doc.at_xpath("/config/modules/#{mm_name}/version")

						# TODO same for:
						# '/config/frontend/events/*'
						# '/config/adminhtml/events/*'
						doc.xpath('/config/global/events/*').each do |node|
							# puts node
							event = node.name
							observers = @global_events_observers[event] ||= {}

							# puts node if mm_name == 'Enterprise_Reminder'

							node.xpath("observers/*").each do |observer_node|
								observer_name = observer_node.name
								if observers.include? observer_name
									mod_first  = observers[observer_name][:defined]
									mod_second = mm_name
									@warnings << "event:#{event} observer:#{observer_name} - defined in #{mod_first} and redefined in #{mod_second}"
									# TODO check if there is a dependency path between mod_first and mod_second
									# print_module(mod_first)
									# print_module(mod_second)
								end
								observers[observer_name] = {
									:class  => observer_node.at_xpath('class').content,
									:method => observer_node.at_xpath('method').content,
									:defined => mm_name,
								}
							end

							@global_events_observers[event] = observers
						end

					end
				end

			end
		end

		def modules()
			Hash[tsort.map { |name| [name, @modules[name]] }]
		end

		def observers()
			@global_events_observers
		end

		def is_active_module?(name)
			@modules.include?(name) && @modules[name][:active]
		end

		def print_module(name)
			puts @modules[name]
		end

		def print_warnings()
			puts @warnings
		end

		def tsort_each_node(&block)
			@modules.each_key(&block)
		end

		def tsort_each_child(node, &block)
			@modules[node][:dependencies].each(&block)
		end

		private

		def load_module_definition(file, xml_node)
			name = xml_node.name
			config = {
				:active       => xml_node.at_xpath('active').content == 'true',
				:code_pool    => xml_node.at_xpath('codePool').content,
				:dependencies => xml_node.xpath('depends/*').map(&:name),
				:defined      => file,
			}
			if @modules.include? name then
				# TODO test this
				@warnings << "module:#{name} - duplicate module definition (#{@modules[name][:defined]} and file)"
			end
			@modules[name] = config
		end

	end
end
