require 'SVG/Graph/TimeSeries'

class GraphsController < ApplicationController
    unloadable

    ############################################################################
    # Initialization
    ############################################################################
    
    menu_item :issues, :only => [:issue_growth, :old_issues, :bug_growth]

    before_filter :find_version, :only => [:target_version_graph]
    before_filter :confirm_issues_exist, :only => [:issue_growth]
    before_filter :find_optional_project, :only => [:issue_growth_graph]
    before_filter :find_open_issues, :only => [:old_issues, :issue_age_graph]
    before_filter :find_bug_issues, :only => [:bug_growth, :bug_growth_graph]
	
    helper IssuesHelper
    
    ############################################################################
    # My Page block graphs
    ############################################################################
    # Displays a ring of issue assignement changes around the current user
    def recent_assigned_to_changes_graph
        # Get the top visible projects by issue count
        sql = " select u1.id as old_user, u2.id as new_user, count(*) as changes_count"
        sql << " from journals as j"
        sql << " left join journal_details as jd on j.id = jd.journal_id"
        sql << " left join users as u1 on jd.old_value = u1.id"
        sql << " left join users as u2 on jd.value = u2.id"
        sql << " where journalized_type = 'issue' and prop_key = 'assigned_to_id' and  DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY) <= j.created_on"
        sql << " and (u1.id = #{User.current.id} or u2.id = #{User.current.id})"
        sql << " and u1.id <> 0 and u2.id <> 0"
        sql << " group by old_value, value"
        @assigned_to_changes = ActiveRecord::Base.connection.select_all(sql)
        user_ids = @assigned_to_changes.collect { |change| [change["old_user"].to_i, change["new_user"].to_i] }.flatten.uniq
        user_ids.delete(User.current.id)
        @users = User.find(:all, :conditions => "id IN ("+user_ids.join(',')+")").index_by { |user| user.id } unless user_ids.empty?
        headers["Content-Type"] = "image/svg+xml"
        render :layout => false
    end
    
    # Displays a ring of issue status changes
    def recent_status_changes_graph
        # Get the top visible projects by issue count
        sql = " select is1.id as old_status, is2.id as new_status, count(*) as changes_count"
        sql << " from journals as j"
        sql << " left join journal_details as jd on j.id = jd.journal_id"
        sql << " left join issue_statuses as is1 on jd.old_value = is1.id"
        sql << " left join issue_statuses as is2 on jd.value = is2.id"
        sql << " where journalized_type = 'issue' and prop_key = 'status_id' and  DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY) <= created_on"
        sql << " group by old_value, value"
        sql << " order by is1.position, is2.position"
        @status_changes = ActiveRecord::Base.connection.select_all(sql)
        @issue_statuses = IssueStatus.find(:all).sort { |a,b| a.position<=>b.position }
        headers["Content-Type"] = "image/svg+xml"
        render :layout => false
    end
    
    
    ############################################################################
    # Graph pages
    ############################################################################
    # Displays total number of issues over time
    def issue_growth
    end
    
    # Displays created vs update date on open issues over time    
    def old_issues
        @issues_by_created_on = @issues.sort {|a,b| a.created_on<=>b.created_on} 
        @issues_by_updated_on = @issues.sort {|a,b| a.updated_on<=>b.updated_on}
    end
    # Displays created vs update date on bugs over time    
    def bug_growth
        @bug_by_created = @bugs.group_by {|issue| issue.created_on.to_date }.sort
    end
        
    ############################################################################
    # Embedded graphs for graph pages
    ############################################################################
    # Displays projects by total issues over time
    def issue_growth_graph
    
        # Initialize the graph
        graph = SVG::Graph::TimeSeries.new({
            :area_fill => true,
            :height => Integer(Setting.plugin_redmine_graphs['graph_height']),
            :min_y_value => 0,
            :no_css => true,
            :show_x_guidelines => true,
            :scale_x_integers => true,
            :scale_y_integers => true,
            :show_data_points => false,
            :show_data_values => false,
            :stagger_x_labels => true,
            :style_sheet => "/plugin_assets/redmine_graphs/stylesheets/issue_growth.css",
            :width => Integer(Setting.plugin_redmine_graphs['graph_width']),
            :x_label_format => "%Y-%m-%d"
        })
        
        # Get the top visible projects by issue count
        sql = "SELECT project_id, COUNT(*) as issue_count"
        sql << " FROM #{Issue.table_name}"
        sql << " LEFT JOIN #{Project.table_name} ON #{Issue.table_name}.project_id = #{Project.table_name}.id"
        sql << " WHERE (%s)" % Project.allowed_to_condition(User.current, :view_issues)
        unless @project.nil?
            sql << " AND (project_id = #{@project.id}"
            sql << "    OR project_id IN (%s)" % @project.descendants.active.visible.collect { |p| p.id }.join(',') unless @project.descendants.active.visible.empty?
            sql << " )"
        end 
        sql << " GROUP BY project_id"
        sql << " ORDER BY issue_count DESC"
        sql << " LIMIT 6"
        top_projects = ActiveRecord::Base.connection.select_all(sql).collect { |p| p["project_id"] }
        
        sql = "SELECT project_id, date(#{Issue.table_name}.created_on) as date, COUNT(*) as issue_count"
        sql << " FROM #{Issue.table_name}"
        sql << " WHERE project_id IN (%s)" % top_projects.compact.join(',')
        sql << " GROUP BY project_id, date"
        issue_counts = ActiveRecord::Base.connection.select_all(sql).group_by { |c| c["project_id"] }

        # Generate the created_on lines
        top_projects.each do |project_id|
            counts = Array(issue_counts[project_id])
            created_count = 0
            created_on_line = Hash.new
            created_on_line[(Date.parse( Array(counts).first["date"].to_s )-1).to_s] = 0
            counts.each { |count| created_count += count["issue_count"].to_i; created_on_line[count["date"].to_s] = created_count }
            created_on_line[Date.today.to_s] = created_count
            graph.add_data({
                :data =>  Array(created_on_line).sort.flatten,
                :title => Project.find(project_id).to_s
            })
        end
        
        # Compile the graph
        headers["Content-Type"] = "image/svg+xml"
        send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
    end

    # Displays issues by creation date, cumulatively
    def issue_age_graph
    
        # Initialize the graph
        graph = SVG::Graph::TimeSeries.new({
            :area_fill => true,
            :height => Integer(Setting.plugin_redmine_graphs['graph_height']),
            :min_y_value => 0,
            :no_css => true,
            :show_x_guidelines => true,
            :scale_x_integers => true,
            :scale_y_integers => true,
            :show_data_points => false,
            :show_data_values => false,
            :stagger_x_labels => true,
            :style_sheet => "/plugin_assets/redmine_graphs/stylesheets/issue_age.css",
            :width => Integer(Setting.plugin_redmine_graphs['graph_width']),
            :x_label_format => "%b %d"
        })

        # Group issues
        issues_by_created_on = @issues.group_by {|issue| issue.created_on.to_date }.sort
        issues_by_updated_on = @issues.group_by {|issue| issue.updated_on.to_date }.sort
        
        # Generate the created_on line
        created_count = 0
        created_on_line = Hash.new
        issues_by_created_on.each { |created_on, issues| created_on_line[(created_on-1).to_s] = created_count; created_count += issues.size; created_on_line[created_on.to_s] = created_count }
        created_on_line[Date.today.to_s] = created_count
        graph.add_data({
            :data => created_on_line.sort.flatten,
            :title => l(:field_created_on)
        }) unless issues_by_created_on.empty?
        
        # Generate the closed_on line
        updated_count = 0
        updated_on_line = Hash.new
        issues_by_updated_on.each { |updated_on, issues| updated_on_line[(updated_on-1).to_s] = updated_count; updated_count += issues.size; updated_on_line[updated_on.to_s] = updated_count }
        updated_on_line[Date.today.to_s] = updated_count
        graph.add_data({
            :data => updated_on_line.sort.flatten,
            :title => l(:field_updated_on)
        }) unless issues_by_updated_on.empty?
        
        # Compile the graph
        headers["Content-Type"] = "image/svg+xml"
        send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
    end
    
	# Displays bugs over time
    def bug_growth_graph
    
        # Initialize the graph
        graph = SVG::Graph::TimeSeries.new({
            :area_fill => true,
            :height => Integer(Setting.plugin_redmine_graphs['graph_height']),
            :min_y_value => 0,
            :no_css => true,
            :show_x_guidelines => true,
            :scale_x_integers => true,
            :scale_y_integers => true,
            :show_data_points => false,
            :show_data_values => false,
            :stagger_x_labels => true,
            :style_sheet => "/plugin_assets/redmine_graphs/stylesheets/bug_growth.css",
            :width => Integer(Setting.plugin_redmine_graphs['graph_width']),
            :x_label_format => "%Y-%m-%d"
        })

        # Group issues
        bug_by_created_on = @bugs.group_by {|issue| issue.created_on.to_date }.sort
        bug_by_updated_on = @bugs.delete_if {|issue| !issue.closed? }.group_by {|issue| issue.updated_on.to_date }.sort
		
        # Generate the created_on line
        created_count = 0
        created_on_line = Hash.new
        bug_by_created_on.each { |created_on, bugs| created_on_line[(created_on-1).to_s] = created_count; created_count += bugs.size; created_on_line[created_on.to_s] = created_count }
        created_on_line[Date.today.to_s] = created_count
        graph.add_data({
            :data => created_on_line.sort.flatten,
            :title => l(:field_created_on)
        }) unless bug_by_created_on.empty?
        
        # Generate the closed_on line
        updated_count = 0
        updated_on_line = Hash.new
        bug_by_updated_on.each { |updated_on, bugs| updated_on_line[(updated_on-1).to_s] = updated_count; updated_count += bugs.size; updated_on_line[updated_on.to_s] = updated_count }
        updated_on_line[Date.today.to_s] = updated_count
        graph.add_data({
            :data => updated_on_line.sort.flatten,
            :title => l(:label_graphs_closed_bugs)
        }) unless bug_by_updated_on.empty?
        
        # Compile the graph
        headers["Content-Type"] = "image/svg+xml"
        send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
    end
	
	# Displays open and total issue counts over time
    def target_version_graph

        # Initialize the graph
        graph = SVG::Graph::TimeSeries.new({
            :area_fill => true,
            :height => Integer(Setting.plugin_redmine_graphs['graph_height']),
            :no_css => true,
            :show_x_guidelines => true,
            :scale_x_integers => true,
            :scale_y_integers => true,
            :show_data_points => true,
            :show_data_values => false,
            :stagger_x_labels => true,
            :style_sheet => "/plugin_assets/redmine_graphs/stylesheets/target_version.css",
            :width => Integer(Setting.plugin_redmine_graphs['graph_width']),
            :x_label_format => "%b %d"
        })

        # Group issues
        issues_by_created_on = @version.fixed_issues.group_by {|issue| issue.created_on.to_date }.sort
        issues_by_updated_on = @version.fixed_issues.group_by {|issue| issue.updated_on.to_date }.sort
        issues_by_closed_on = @version.fixed_issues.collect {|issue| issue if issue.closed? }.compact.group_by {|issue| issue.updated_on.to_date }.sort
                    
        # Set the scope of the graph
        scope_end_date = issues_by_updated_on.last.first
        scope_end_date = @version.effective_date if !@version.effective_date.nil? && @version.effective_date > scope_end_date
        scope_end_date = Date.today if !@version.completed?
        line_end_date = Date.today
        line_end_date = scope_end_date if scope_end_date < line_end_date
                    
        # Generate the created_on line
        created_count = 0
        created_on_line = Hash.new
        issues_by_created_on.each { |created_on, issues| created_on_line[(created_on-1).to_s] = created_count; created_count += issues.size; created_on_line[created_on.to_s] = created_count }
        created_on_line[scope_end_date.to_s] = created_count
        graph.add_data({
            :data => created_on_line.sort.flatten,
            :title => l(:label_total).capitalize
        })
        
        # Generate the closed_on line
        closed_count = 0
        closed_on_line = Hash.new
        issues_by_closed_on.each { |closed_on, issues| closed_on_line[(closed_on-1).to_s] = closed_count; closed_count += issues.size; closed_on_line[closed_on.to_s] = closed_count }
        closed_on_line[line_end_date.to_s] = closed_count
        graph.add_data({
            :data => closed_on_line.sort.flatten,
            :title => l(:label_closed_issues).capitalize
        })
        
        # Add the version due date marker
        graph.add_data({
            :data => [@version.effective_date.to_s, created_count],
            :title => l(:field_due_date).capitalize
        }) unless @version.effective_date.nil?
        
        
        # Compile the graph
        headers["Content-Type"] = "image/svg+xml"
        send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
    end
    
    
    ############################################################################
    # Private methods
    ############################################################################
    private
            
    def confirm_issues_exist
        find_optional_project
        if !@project.nil?
            ids = [@project.id]
            ids += @project.descendants.active.visible.collect(&:id)
            @issues = Issue.visible.find(:first, :conditions => ["#{Project.table_name}.id IN (?)", ids])
        else
            @issues = Issue.visible.find(:first)
        end
    rescue ActiveRecord::RecordNotFound
        render_404
    end
    
    def find_open_issues
        find_optional_project
        if !@project.nil?
            ids = [@project.id]
            ids += @project.descendants.active.visible.collect(&:id)
            @issues = Issue.visible.find(:all, :include => [:status], :conditions => ["#{IssueStatus.table_name}.is_closed=? AND #{Project.table_name}.id IN (?)", false, ids])
        else
            @issues = Issue.visible.find(:all, :include => [:status], :conditions => ["#{IssueStatus.table_name}.is_closed=?", false])
        end
    rescue ActiveRecord::RecordNotFound
        render_404
    end
	
	def find_bug_issues
        find_optional_project
        if !@project.nil?
            ids = [@project.id]
            ids += @project.descendants.active.visible.collect(&:id)
            tracker_ids = [1, 9, 10]
            @bugs= Issue.visible.find(:all, :include => [:status], :conditions => ["#{Issue.table_name}.tracker_id IN (?) AND #{Project.table_name}.id IN (?)", tracker_ids, ids])
        else
            @bugs= Issue.visible.find(:all, :include => [:status], :conditions => ["#{Issue.table_name}.tracker_id IN (?)", tracker_ids])
        end
    rescue ActiveRecord::RecordNotFound
        render_404
    end
	        
    def find_optional_project
        @project = Project.find(params[:project_id]) unless params[:project_id].blank?
        deny_access unless User.current.allowed_to?(:view_issues, @project, :global => true)
    rescue ActiveRecord::RecordNotFound
        render_404
    end
    
    def find_version
        @version = Version.find(params[:id])
        deny_access unless User.current.allowed_to?(:view_issues, @version.project)
    rescue ActiveRecord::RecordNotFound
        render_404
    end
end
