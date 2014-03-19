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

      def ontology options={}
        options[:apikey] ||= self.bioportal_api_key unless self.bioportal_api_key.nil?

        return nil if self.bioportal_concept.nil?
        return self.bioportal_concept.get_ontology options
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

    def error_check(doc)
      response = nil
      error={}
      begin
        doc.elements.each("org.ncbo.stanford.bean.response.ErrorStatusBean"){ |element|
          error[:error] = true
          error[:shortMessage] = element.elements["shortMessage"].get_text.value.strip
          error[:longMessage] =element.elements["longMessage"].get_text.value.strip
          response = error
        }
      rescue
      end

      return response
    end

    def parse_search_result element
      search_item={}
      search_item[:ontology_display_label]=element.first.find(element.path+"/ontologyDisplayLabel").first.content rescue nil
      search_item[:ontology_version_id]=element.first.find(element.path+"/ontologyVersionId").first.content rescue nil
      search_item[:ontology_id]=element.first.find(element.path+"/ontologyId").first.content rescue nil
      search_item[:record_type]=element.first.find(element.path+"/recordType").first.content rescue nil
      search_item[:concept_id]=element.first.find(element.path+"/conceptId").first.content rescue nil
      search_item[:concept_id_short]=element.first.find(element.path+"/conceptIdShort").first.content rescue nil
      search_item[:preferred_name]=element.first.find(element.path+"/preferredName").first.content rescue nil
      search_item[:contents]=element.first.find(element.path+"/contents").first.content rescue nil
      return search_item
    end

    def process_concepts_xml doc
      doc.find("/*/data/classBean").each{ |element|
        return process_concept_bean_xml(element)
      }      
    end

    def parse_ontologies_xml doc
      ontologies=[]
      doc.find("/*/data/list/ontologyBean").each{ |element|
        ontologies << parse_ontology_bean_xml(element)
      }
      return ontologies
    end


  end
    
end

ActiveRecord::Base.send(:include,BioPortal::Acts)

