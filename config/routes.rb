ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:project_id/issues/old', :controller => 'graphs', :action => 'old_issues'
  map.connect 'issues/old', :controller => 'graphs', :action => 'old_issues'
  map.connect ':project_id/issue_age_graph', :controller => 'graphs', :action => 'issue_age_graph'
  map.connect 'projects/:project_id/issues/growth', :controller => 'graphs', :action => 'issue_growth'
  map.connect 'issues/growth', :controller => 'graphs', :action => 'issue_growth'
  map.connect ':project_id/issue_growth_graph', :controller => 'graphs', :action => 'issue_growth_graph'
  map.connect 'graphs/recent-status-changes', :controller=>"graphs", :action=>"recent_status_changes_graph"
  map.connect 'graphs/recent-assigned-to-changes', :controller=>"graphs", :action=>"recent_assigned_to_changes_graph"
  map.connect 'graphs/target-version/:id', :controller=>"graphs", :action=>"target_version_graph" 
end
