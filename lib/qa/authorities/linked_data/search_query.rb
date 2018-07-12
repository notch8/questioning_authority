# This module has the primary QA search method.  It also includes methods to process the linked data results and convert
# them into the expected QA json results format.
module Qa::Authorities
  module LinkedData
    class SearchQuery
      include Qa::Authorities::LinkedData::RdfHelper

      # @param [SearchConfig] search_config The search portion of the config
      def initialize(search_config)
        @search_config = search_config
      end

      attr_reader :search_config
      attr_reader :graph

      delegate :subauthority?, :supports_sort?, to: :search_config

      # Search a linked data authority
      # @param [String] the query
      # @param [Symbol] (optional) language: language used to select literals when multi-language is supported (e.g. :en, :fr, etc.)
      # @param [Hash] (optional) replacements: replacement values with { pattern_name (defined in YAML config) => value }
      # @param [String] subauth: the subauthority to query
      # @return [String] json results
      # @example Json Results for Linked Data Search
      #   [ {"uri":"http://id.worldcat.org/fast/5140","id":"5140","label":"Cornell, Joseph"},
      #     {"uri":"http://id.worldcat.org/fast/72456","id":"72456","label":"Cornell, Sarah Maria, 1802-1832"},
      #     {"uri":"http://id.worldcat.org/fast/409667","id":"409667","label":"Cornell, Ezra, 1807-1874"} ]
      def search(query, language: nil, replacements: {}, subauth: nil, include_performance_data: false)
        raise Qa::InvalidLinkedDataAuthority, "Unable to initialize linked data search sub-authority #{subauth}" unless subauth.nil? || subauthority?(subauth)
        language ||= search_config.language
        url = search_config.url_with_replacements(query, subauth, replacements)
        Rails.logger.info "QA Linked Data search url: #{url}"

        access_start_dt = Time.now
        @graph = get_linked_data(url)
        access_end_dt = Time.now
        access_time_s = access_end_dt - access_start_dt
        Rails.logger.info("Time to receive data from authority: #{access_time_s}s")

        parse_start_dt = Time.now
        json = parse_search_authority_response(language)
        parse_end_dt = Time.now
        parse_time_s = parse_end_dt - parse_start_dt
        Rails.logger.info("Time to convert data to json: #{parse_time_s}s")
        json = append_performance_data(json, access_time_s, parse_time_s) if include_performance_data
        json
      end

      private

        def parse_search_authority_response(language)
          @graph = filter_language(graph, language) unless language.nil?
          @graph = filter_out_blanknodes(graph)
          results = extract_preds(graph, preds_for_search(include_sort: true, include_context: true))
          consolidated_results = consolidate_search_results(results, include_context: true)
          json_results = convert_search_to_json(consolidated_results)
          sort_search_results(json_results)
        end

        def preds_for_search(include_sort: true, include_context: false)
          preds = { required: required_search_preds, optional: optional_search_preds(include_sort) }
          preds[:context] = context_search_preds if include_context
          preds
        end

        def required_search_preds
          label_pred_uri = search_config.results_label_predicate
          raise Qa::InvalidConfiguration, "required label_predicate is missing in search configuration for LOD authority #{auth_name}" if label_pred_uri.nil?
          { label: label_pred_uri }
        end

        def optional_search_preds(include_sort)
          preds = {}
          preds[:altlabel] = search_config.results_altlabel_predicate unless search_config.results_altlabel_predicate.nil?
          preds[:id] = search_config.results_id_predicate unless search_config.results_id_predicate.nil?
          preds[:sort] = search_config.results_sort_predicate unless search_config.results_sort_predicate.nil? || !include_sort
          preds[:selector] = search_config.results_selector_predicate if search_config.select_results_based_on_predicate?
          preds
        end

        # @returns hash of predicates for additional context
        # @example hash of predicates
        #   {
        #     :"Alternate Label" => #<RDF::URI http://www.w3.org/2004/02/skos/core#altLabel>,
        #     :Broader => #<RDF::URI http://www.w3.org/2004/02/skos/core#broader>,
        #     :Narrower => #<RDF::URI http://www.w3.org/2004/02/skos/core#narrower>,
        #     :"Exact Match" => #<RDF::URI http://www.w3.org/2004/02/skos/core#exactMatch>,
        #     :Note => #<RDF::URI http://www.w3.org/2004/02/skos/core#note>
        #   }
        def context_search_preds
          search_config.results_context || {}
        end

        def consolidate_search_results(results, include_context: false, process_all: false, default_uri: nil)
          return {} if results.nil? || !results.count.positive?
          consolidated_results = convert_statements_to_hash(results, include_context, process_all, default_uri)
          consolidated_results = sort_multiple_result_values(consolidated_results) # sorts and converts to strings
          consolidated_results = fill_in_secondary_context_values(consolidated_results) if include_context
          consolidated_results
        end

        # Converts graph statements into a hash
        # @returns hash of statements in results graph
        # @example hash of statments
        #   {
        #     "http://id.loc.gov/authorities/genreForms/gf2014027106"=>
        #       {
        #         :id=>"http://id.loc.gov/authorities/genreForms/gf2014027106",
        #         :label=>[#<RDF::Literal:0x3fe50b55a020("Soul music"@en)>],
        #         :altlabel=>[],
        #         :sort=>[#<RDF::Literal:0x3fe50b54acec("1")>],
        #         :context=>{
        #           :"Alternate Label"=>[],
        #           :Broader=>[#<RDF::URI:0x3fe5099785c8 URI:http://id.loc.gov/authorities/genreForms/gf2014027009>],
        #           :Narrower=>[#<RDF::URI:0x3fe50b57e36c URI:http://id.loc.gov/authorities/genreForms/gf2014026998>, #<RDF::URI:0x3fe509981574 URI:http://id.loc.gov/authorities/genreForms/gf2014027098>],
        #           :"Exact Match"=>[],
        #           :Note=>[]
        #         }
        #       },
        #     "http://id.loc.gov/authorities/genreForms/gf2014026998"=>
        #       {
        #         :id=>"http://id.loc.gov/authorities/genreForms/gf2014026998",
        #         :label=>[#<RDF::Literal:0x3fe50b73d950("Philadelphia soul (Music)"@en)>],
        #         :altlabel=>[],
        #         :sort=>[#<RDF::Literal:0x3fe50b6f9854("2")>],
        #         :context=>{
        #           :"Alternate Label"=>[#<RDF::Literal:0x3fe50b725328("Philly soul (Music)")>, #<RDF::Literal:0x3fe50b7247fc("Sound of Philadelphia (Music)")>],
        #           :Broader=>[#<RDF::URI:0x3fe50b721de0 URI:http://id.loc.gov/authorities/genreForms/gf2014027106>],
        #           :Narrower=>[],
        #           :"Exact Match"=>[],
        #           :Note=>[]
        #         }
        #       },
        #     }
        def convert_statements_to_hash(results, include_context, process_all, default_uri)
          consolidated_results = {}
          results.each do |statement|
            stmt_hash = statement.to_h
            uri = stmt_hash[:uri].to_s
            uri = default_uri unless uri.present?

            consolidated_hash = init_consolidated_hash(consolidated_results, uri, stmt_hash[:id].to_s)
            next unless process_all || result_statement?(stmt_hash)

            consolidated_hash[:label] = object_value(stmt_hash, consolidated_hash, :label, false)
            consolidated_hash[:altlabel] = object_value(stmt_hash, consolidated_hash, :altlabel, false)
            consolidated_hash[:sort] = object_value(stmt_hash, consolidated_hash, :sort, false)

            consolidated_hash = extract_context_values(stmt_hash, consolidated_hash) if include_context

            consolidated_results[uri] = consolidated_hash
          end
          consolidated_results
        end

        def extract_context_values(stmt_hash, consolidated_hash)
          current_context = consolidated_hash[:context] || {}
          context = {}
          context_search_preds.each_key do |k|
            context[k] = object_value(stmt_hash, current_context, k, false)
          end
          consolidated_hash[:context] = context
          consolidated_hash
        end

        def sort_multiple_result_values(consolidated_results)
          consolidated_results.each do |uri, predicate_hash|
            predicate_hash[:label] = sort_string_by_language predicate_hash[:label]
            predicate_hash[:altlabel] = sort_string_by_language predicate_hash[:altlabel]
            predicate_hash[:sort] = sort_string_by_language predicate_hash[:sort]
            consolidated_results[uri] = predicate_hash
          end
          consolidated_results
        end

        def fill_in_secondary_context_values(consolidated_results)
          return consolidated_results unless search_config.supports_context?
          consolidated_results.each do |uri, predicate_hash|
            context = predicate_hash[:context]
            context_search_preds.each_key do |k|
              if context[k].first.is_a? RDF::URI
                filled_context = {}
                blank_count = 0
                context[k].each do |context_uri|
                  expanded_results = extract_preds_for_uri(graph, preds_for_search(include_context: false, include_sort: false), context_uri)
                  expanded_results = consolidate_search_results(expanded_results, include_context: false, process_all: true, default_uri: context_uri.to_s)
                  if expanded_results.blank?
                    blank_count += 1
                    expanded_results[context_uri.to_s] = {}
                  end
                  filled_context.merge!(expanded_results)
                end
                if blank_count == context[k].count
                  # if all are blank, then just return the keys
                  filled_context = filled_context.keys
                end
                context[k] = filled_context
              else
                context[k] = sort_string_by_language context[k]
              end
            end
            predicate_hash[:context] = context
            consolidated_results[uri] = predicate_hash
          end
          consolidated_results
        end

        def result_statement?(stmt_hash)
          return true unless search_config.select_results_based_on_predicate?
          stmt_hash[:selector].present?
        end

        def convert_search_to_json(consolidated_results)
          json_results = []
          consolidated_results.each do |uri, h|
            json_result = { uri: uri, id: h[:id], label: full_label(h[:label], h[:altlabel]), sort: h[:sort] }
            json_result[:context] = context_json(h) if search_config.supports_context?
            json_results << json_result
          end
          json_results
        end

        def context_json(consolidated_results_hash)
          context_json = {}
          context_search_preds.each_key do |k|
            if consolidated_results_hash[:context][k].is_a? Hash
              json_value = []
              consolidated_results_hash[:context][k].each do |uri, data|
                json_value << { uri: uri, id: data[:id], label: full_label(data[:label], data[:altlabel]) }
              end
            else
              json_value = consolidated_results_hash[:context][k]
            end
            context_json[k] = json_value
          end
          context_json
        end

        def full_label(label = [], altlabel = [])
          lbl = wrap_labels(label)
          lbl += " (#{altlabel.join(', ')})" unless altlabel.nil? || altlabel.length <= 0
          lbl = lbl.slice(0..95) + '...' if lbl.length > 98
          lbl.strip
        end

        def wrap_labels(labels)
          return "" if labels.blank?
          lbl = labels.join(', ') if labels.size.positive?
          lbl = '[' + lbl + ']' if labels.size > 1
          lbl
        end

        def sort_search_results(json_results) # rubocop:disable Metrics/MethodLength
          return json_results unless supports_sort?
          json_results.sort! do |a, b|
            cmp = sort_when_missing_sort_predicate(a, b)
            next cmp unless cmp.nil?

            cmp = numeric_sort(a, b)
            next cmp unless cmp.nil?

            as = a[:sort].collect(&:downcase)
            bs = b[:sort].collect(&:downcase)
            cmp = 0
            0.upto([as.size, bs.size].max - 1) do |i|
              cmp = sort_when_same_but_one_has_more_values(as, bs, i)
              break unless cmp.nil?

              cmp = (as[i] <=> bs[i])
              break if cmp.nonzero? # stop checking as soon as a value in the two lists are different
            end
            cmp
          end
          json_results.each { |h| h.delete(:sort) }
        end

        def sort_when_missing_sort_predicate(a, b)
          return 0 unless a.key?(:sort) || b.key?(:sort) # leave unchanged if both are missing
          return -1 unless a.key? :sort # consider missing a value lower than existing b value
          return 1 unless b.key? :sort # consider missing b value lower than existing a value
          nil
        end

        def sort_when_same_but_one_has_more_values(as, bs, current_list_size)
          return -1 if as.size <= current_list_size # consider shorter a list of values lower then longer b list
          return 1 if bs.size <= current_list_size # consider shorter b list of values lower then longer a list
          nil
        end

        def numeric_sort(a, b)
          return nil if a[:sort].size > 1
          return nil if b[:sort].size > 1
          return nil unless s_is_i? a[:sort][0]
          return nil unless s_is_i? b[:sort][0]
          Integer(a[:sort][0]) <=> Integer(b[:sort][0])
        end

        def s_is_i?(s)
          /\A[-+]?\d+\z/ === s # rubocop:disable Style/CaseEquality
        end

        def append_performance_data(results, access_time_s, parse_time_s)
          performance = { result_count: results.size,
                          fetch_time_s: access_time_s,
                          normalization_time_s: parse_time_s,
                          total_time_s: (access_time_s + parse_time_s) }
          { performance: performance, results: results }
        end
    end
  end
end
