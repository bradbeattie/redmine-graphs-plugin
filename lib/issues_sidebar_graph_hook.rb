# Provides a link to the issue age graph on the issue index page
class IssuesSidebarGraphHook < Redmine::Hook::ViewListener
  def view_issues_sidebar_issues_bottom(context = { })
  	output = "<h3>Graphs</h3>"
  	output << link_to(l(:label_graphs_old_issues), {:controller => 'graphs', :action => 'old_issues'}) if context[:project].nil?
  	output << link_to(l(:label_graphs_old_issues), {:controller => 'graphs', :action => 'old_issues', :project_id => context[:project]}) unless context[:project].nil?
  	output << "<br/>"
  	output << link_to(l(:label_graphs_issue_growth), {:controller => 'graphs', :action => 'issue_growth'}) if context[:project].nil?
  	output << link_to(l(:label_graphs_issue_growth), {:controller => 'graphs', :action => 'issue_growth', :project_id => context[:project]}) unless context[:project].nil?
  	output << "<br/>"
  	return output
  end
end