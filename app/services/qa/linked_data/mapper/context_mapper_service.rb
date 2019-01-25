# Provide service for mapping predicates to object values.
module Qa
  module LinkedData
    module Mapper
      class ContextMapperService
        class_attribute :graph_service
        self.graph_service = Qa::LinkedData::GraphService

        class << self
          # Extract predicates specified in the predicate_map from the graph and return as a value map for a single subject URI.
          # @param graph [RDF::Graph] the graph from which to extract result values
          # @param context_map [Qa::LinkedData::Config::ContextMap] defines properties to extract from the graph to provide additional context
          # @param subject_uri [RDF::URI] the subject within the graph for which the values are being extracted
          # @return [<Hash<Symbol><Array<Object>>] mapped context values and information with hash of map key = array of object values for predicates identified in predicate_map.
          # @example value map for a single result
          #   {:uri=>[#<RDF::URI:0x3fcff54a829c URI:http://id.loc.gov/authorities/names/n2010043281>],
          #    :id=>[#<RDF::Literal:0x3fcff4a367b4("n2010043281")>],
          #    :label=>[#<RDF::Literal:0x3fcff54a9a98("Valli, Sabrina"@en)>],
          #    :altlabel=>[],
          #    :sort=>[#<RDF::Literal:0x3fcff54b4c18("2")>]}
          def map_context(graph:, context_map:, subject_uri:)
            context = []
            context_map.properties.each do |property_map|
              values = fetch_values(property_map, graph, subject_uri)
              next if values.blank?
              context << construct_context(property_map, values)
            end
            context
          end

          private

            def fetch_values(property_map, graph, subject_uri)
              output = property_map.ldpath_program.evaluate subject_uri, graph
              output.present? ? output['property'].uniq : nil
            rescue
              'PARSE ERROR'
            end

            def construct_context(property_map, values)
              property_info = {}
              property_info["group"] = property_map.group_id if property_map.group?
              property_info["property"] = property_map.label
              property_info["values"] = values
              property_info["selectable"] = property_map.selectable?
              property_info["drillable"] = property_map.drillable?
              property_info
            end
        end
      end
    end
  end
end
