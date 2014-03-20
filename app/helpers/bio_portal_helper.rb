

module BioPortalHelper

  def visualise_ontology model,options={}
    options[:show_concept]||=false
    concept_id=nil
    concept_id=model.concept_uri if options[:show_concept] && !model.concept_uri.nil?
    ontology_id ||= model.ontology_id
    apikey=options[:apikey]
    render(:partial=>"bioportal/bioportal_visualise",:locals=>{:ontology_id=>ontology_id,:concept_id=>concept_id,:apikey=>apikey})
  end



end

