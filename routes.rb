map.connect 'projects/:project_id/issues/old', :controller => 'graphs', :action => 'old_issues'
map.connect 'issues/old', :controller => 'graphs', :action => 'old_issues'