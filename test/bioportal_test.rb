require_relative 'test_helper'
require 'pp'


class BioportalTest < Test::Unit::TestCase
  
  include BioPortal::RestAPI

  def setup
    @options={:apikey=>read_bioportal_api_key}
  end
  
  def test_search
    @options[:pagesize]=10
    res,pages = search "Escherichia coli",@options

    assert !res.empty?
    assert pages>50
    assert_equal 10,res.size

    found = res.find{|r| r[:class_id]=="http://purl.bioontology.org/ontology/MSH/D004926"}
    assert_not_nil(found)
    assert_equal "http://data.bioontology.org/ontologies/MESH",found[:ontology_link]
    assert_equal "Medical Subject Headings",found[:ontology_name]
    assert_equal "MESH",found[:ontology_acronym]

  end

  def test_search_specific_ontologies
    @options[:pagesize]=150
    @options[:ontologies]="NCBITAXON"
    res,pages = search "cat",@options

    assert !res.empty?
    assert res.size>50
    assert_equal 1,pages

    assert_empty(res.select{|r| r[:ontology_link]!="http://data.bioontology.org/ontologies/NCBITAXON"})
  end

  def test_get_concept
    concept = get_concept "NCBITAXON","http://purl.obolibrary.org/obo/NCBITaxon_431941",@options
    assert_not_nil concept, "concept returned should not be nil"
    assert_equal "Rana megatympanum",concept[:label]

    assert concept[:synonyms].include?("tobacco frog"),"synonyms should contain tobacco frog"
    assert_equal [], concept[:definitions]
  end

  def test_override_base_url
    class << self
      def bioportal_base_rest_url
        "http://google.com/fred"
      end
    end
    assert_raise(OpenURI::HTTPError) { get_concept "NCBITAXON","http://purl.obolibrary.org/obo/NCBITaxon_431941",{:light=>true}  }
  end

  
end
