# Provides a link to the issue age graph on the issue index page
class IssuesSidebarGraphHook < Redmine::Hook::ViewListener
  def view_issues_sidebar_issues_bottom(context = { })
    context[:controller].send(:render_to_string, {
        :partial => 'hooks/redmine_graphs/view_issues_sidebar_issues_bottom',
        :locals => context })
  end
end
