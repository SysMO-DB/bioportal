require 'pp'
module BioPortal
  
  require 'bioportal/engine' if defined?(Rails)
  
  module Acts
    def self.included(mod)
      mod.extend(ClassMethods)
    end

    module ClassMethods
      def linked_to_bioportal(options = {}, &extension)
        options[:base_url]||="http://data.bioontology.org"
        
        has_one :bioportal_concept,:as=>:conceptable,:dependent=>:destroy
        before_save :save_changed_concept
        cattr_accessor :bioportal_base_rest_url, :bioportal_api_key

        self.bioportal_base_rest_url=options[:base_url]
        self.bioportal_api_key=options[:apikey]


        extend BioPortal::Acts::SingletonMethods
        include BioPortal::Acts::InstanceMethods        
      end
    end

    module SingletonMethods
      
    end

    module InstanceMethods
     
      def concept options={}

        options[:apikey] ||= self.bioportal_api_key unless self.bioportal_api_key.nil?

        return nil if self.bioportal_concept.nil?
        begin
          return self.bioportal_concept.get_concept options
        rescue Exception=>e
          return nil
        end
      end

      def ncbi_uri
        concept_uri
      end

      def ncbi_id
        unless ncbi_uri.nil?
          id = ncbi_uri.split("/").last.split("_").last
          id.to_i
        else
          nil
        end
      end


      def ontology_id
        return nil if self.bioportal_concept.nil?
        return self.bioportal_concept.ontology_id
      end


      def concept_uri
        return nil if self.bioportal_concept.nil?
        return self.bioportal_concept.concept_uri
      end

      def ontology_id= value
        check_concept
        self.bioportal_concept.ontology_id=value
      end


      def concept_uri= value
        check_concept
        self.bioportal_concept.concept_uri=value
      end   

      private

      def check_concept
        self.bioportal_concept=BioportalConcept.new if self.bioportal_concept.nil?
      end

      def save_changed_concept
        self.bioportal_concept.save! if !self.bioportal_concept.nil? && self.bioportal_concept.changed?
      end

    end
  end
  

  module RestAPI
    require 'rubygems'
    require 'open-uri'
    require 'uri'

    
    
    def get_concept ontology_acronym,class_id,options={}
      url = "/ontologies/#{ontology_acronym}/classes/#{URI.escape(class_id,":/")}?"
      options.keys.each{|key| url += "#{key.to_s}=#{URI.encode(options[key].to_s)}&"}
      url=bioportal_base_rest_url+url
      json = fetch_json(url)
      concept={}
      concept[:label]=json["prefLabel"]
      concept[:synonyms]=json["synonym"]
      concept[:definitions]=json["definition"]
      concept
    end


    def search query,options={}
      options[:pagesize] ||= 10
      options[:page] ||= 1
      
      search_url="/search?q=%QUERY%&"
      options.keys.each {|key| search_url+="#{key.to_s}=#{URI.encode(options[key].to_s)}&"}
      search_url=search_url[0..-2] #chop of trailing &
      
      search_url=search_url.gsub("%QUERY%",URI.encode(query))
      full_search_path=bioportal_base_rest_url+search_url

      json = fetch_json(full_search_path)

      results = json["collection"].collect do |item|
        res = {}
        res[:ontology_link]=item["links"]["ontology"]
        res[:class_link]=item["links"]["self"]
        res[:preferred_label]=item["prefLabel"]
        res[:synonyms]=item["synonym"] || []
        res[:class_id]=item["@id"]
        populate_ontology_details res,options
        res
      end
      pages = json["pageCount"]

      return results.uniq,pages.to_i
    end

    def populate_ontology_details search_result, options
      apikey = options[:apikey]
      link = search_result[:ontology_link]
      link = link+"?apikey=#{apikey}"
      json = fetch_json(link)

      search_result[:ontology_name]=json["name"]
      search_result[:ontology_acronym]=json["acronym"]
    end

    def fetch_json link
      @@bioportal_json ||={}
      json = @@bioportal_json[link]
      if json.nil?
        json = JSON.parse(open(link).read)
        @@bioportal_json[link]=json
      end
      json
    end


    private
    
    DEFAULT_REST_URL = "http://data.bioontology.org"

    def bioportal_base_rest_url
      DEFAULT_REST_URL
    end

  end
    
end

ActiveRecord::Base.send(:include,BioPortal::Acts)

