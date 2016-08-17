require 'tsort'

module Maruto
	class MagentoConfig
		include TSort

		def initialize(magento_root)

			@modules = {}

			@global_model_groups = {}
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

						config_path = "app/code/#{mm_config[:code_pool]}/#{mm_name.gsub(/_/, '/')}/etc/config.xml"

						if !File.exist?(config_path)
							@warnings << "module:#{mm_name} is defined (#{mm_config[:defined]}) but does not exists (#{config_path})"
							next
						end

						f = File.open(config_path)
						doc = Nokogiri::XML(f) { |config| config.strict }
						f.close

						mm_config[:version] = doc.at_xpath("/config/modules/#{mm_name}/version").content if doc.at_xpath("/config/modules/#{mm_name}/version")

						##########################################################################################
						# MODELS

						doc.xpath('/config/global/models/*').each do |node|
							load_model(mm_name, node)
						end

						if mm_name.start_with? "Mage_" then
							# special case for Mage_NAME modules: if not defined, fallback to Mage_Model_NAME
							group_name = mm_name.sub("Mage_", "").downcase
							if !@global_model_groups.include? group_name then
								@global_model_groups[group_name] = {
									:class   => "#{mm_name}_Model",
									:defined => :fallback,
								}
							end
							if !@global_model_groups[group_name][:class] then
								# TODO warn? => missing dep?
								@global_model_groups[group_name][:class]   = "#{mm_name}_Model"
								@global_model_groups[group_name][:defined] = :fallback
							end
						end

					end
				end # modules().each

				# check if all model_groups have a class attribute
				# TODO write test
				@global_model_groups.each do |group_name, model_group|
					if !model_group[:class] && !group_name.end_with?('_mysql4') then
						@warnings << "module:#{model_group[:define]} model_group:#{group_name} - missing class attribute for model"
					end
				end

			end # Dir.chdir(magento_root)
		end

		def modules()
			Hash[tsort.map { |name| [name, @modules[name]] }]
		end

		def models()
			@global_model_groups
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
				:dependencies => xml_node.xpath('depends/*').map(&:name),
				:defined      => file,
			}
			# deprecated will be deleted
			if xml_node.at_xpath('codePool') then
				config[:code_pool] = xml_node.at_xpath('codePool').content
			else
				#@warnings << "module:#{name} - ..."
			end
			if @modules.include? name then
				#@warnings << "module:#{name} - duplicate module definition (#{@modules[name][:defined]} and file)"
			end
			@modules[name] = config
		end

		def load_model(module_name, xml_node)
			group_name = xml_node.name

			# this xml_node declares a new model
			load_model_definition(module_name, group_name, xml_node) if xml_node.at_xpath('class')

			# this xml_node declares a model rewrite
			load_model_rewrite(module_name, group_name, xml_node)    if xml_node.at_xpath('rewrite')

			if !xml_node.at_xpath('class') && !xml_node.at_xpath('rewrite') && !xml_node.at_xpath('entities')
				@warnings << "module:#{module_name} model_group:#{group_name} - unrecognized model"
			end

		end

		def load_model_definition(module_name, group_name, xml_node)
			# check for redefinition
			if @global_model_groups.include?(group_name) && @global_model_groups[group_name][:class] then
				mod_first  = @global_model_groups[group_name][:defined]
				mod_second = module_name
				@warnings << "model_group:#{group_name} - defined in #{mod_first} and redefined in #{mod_second}"
			end

			# model_group hash could alread have been created (rewrites for this model in another module)
			model_group = @global_model_groups[group_name] ||= {}

			model_group[:class]   = xml_node.at_xpath('class').content
			model_group[:defined] = module_name
			# optional
			model_group[:resource_model] = xml_node.at_xpath('resourceModel').content if xml_node.at_xpath('resourceModel')
		end

		def load_model_rewrite(module_name, group_name, xml_node)
			# check if model_group already defined, else warn missing dependency relation
			# TODO is this an issue or is this allowed?
			# if !@global_model_groups.include? group_name then
			# 	@warnings << "module:#{module_name} - rewrites model_group:#{group_name} which isn't defined yet (missing dependency?)"
			# end

			# model_group and model_group[:rewrites] hashes could alread have been created
			model_group = @global_model_groups[group_name] ||= {}
			rewrites    = model_group[:rewrites]           ||= {}

			xml_node.xpath("rewrite/*").each do |rewrite_node|
				rewrite_name = rewrite_node.name
				if rewrites.include? rewrite_name
					# TODO check if there is a dependency path between mod_first and mod_second?
					mod_first  = rewrites[rewrite_name][:defined]
					mod_second = module_name
					@warnings << "model_group:#{group_name} rewrite:#{rewrite_name} - defined in #{mod_first} and redefined in #{mod_second}"
				end
				rewrites[rewrite_name] = {
					:class   => rewrite_node.content,
					:defined => module_name,
				}
			end
		end
	end
end
