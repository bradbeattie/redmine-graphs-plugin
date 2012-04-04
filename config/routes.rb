ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:project_id/issues/old', :controller => 'graphs', :action => 'old_issues'
  map.connect 'issues/old', :controller => 'graphs', :action => 'old_issues'
  map.connect 'projects/:project_id/issues/growth', :controller => 'graphs', :action => 'issue_growth'
  map.connect 'issues/growth', :controller => 'graphs', :action => 'issue_growth'
end
