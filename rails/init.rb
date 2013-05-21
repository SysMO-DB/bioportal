require 'bioportal'

ActionView::Base.send(:include, BioPortalHelper)
ActiveRecord::Base.send(:include,BioPortal::Acts)
