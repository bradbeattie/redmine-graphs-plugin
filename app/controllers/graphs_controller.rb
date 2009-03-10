require 'SVG/Graph/TimeSeries'

class GraphsController < ApplicationController

	before_filter :find_version, :only => [:target_version_graph]
	before_filter :find_open_issues, :only => [:old_issues, :issue_age_graph]
	before_filter :find_all_issues, :only => [:issue_growth_graph, :issue_growth]
	
	helper IssuesHelper
	
	def issue_growth
	end
	
	# Displays projects by total issues over time
	def issue_growth_graph
	
		# Initialize the graph
		graph = SVG::Graph::TimeSeries.new({
			:height => 300,
			:min_y_value => 0,
			:no_css => true,
			:show_x_guidelines => true,
			:scale_x_integers => true,
			:scale_y_integers => true,
			:show_data_points => false,
			:show_data_values => false,
			:stagger_x_labels => true,
			:style_sheet => "/plugin_assets/redmine_graphs/stylesheets/issue_growth.css",
			:timescale_divisions => "1 weeks",
			:width => 800,
			:x_label_format => "%b %d"
		})

		# Group issues
	  	issues_by_project = @issues.group_by {|issue| issue.project }
		projects_by_size = issues_by_project.collect { |project, issues| [project, issues.size] }.sort { |a,b| b[1]<=>a[1] }[0..5]
		
		# Generate the created_on line
		projects_by_size.each do |project, size| 		
			issues_by_created_on = issues_by_project[project].group_by {|issue| issue.created_on.to_date }.sort
			created_count = 0
			created_on_line = Hash.new
			created_on_line[(issues_by_created_on.first[0]-1).to_s] = 0
		  	issues_by_created_on.each { |created_on, issues| created_count += issues.size; created_on_line[created_on.to_s] = created_count }
		  	created_on_line[Date.today.to_s] = created_count
		  	graph.add_data({
				:data => created_on_line.sort.flatten,
				:title => project.name
		    })
		end
		
	    # Compile the graph
		headers["Content-Type"] = "image/svg+xml"
		send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
	end
	
	def old_issues
	  	@issues_by_created_on = @issues.sort {|a,b| a.created_on<=>b.created_on} 
	  	@issues_by_updated_on = @issues.sort {|a,b| a.updated_on<=>b.updated_on} 
	end

	# Displays issues by creation date, cumulatively
	def issue_age_graph
	
		# Initialize the graph
		graph = SVG::Graph::TimeSeries.new({
			:area_fill => true,
			:height => 300,
			:min_y_value => 0,
			:no_css => true,
			:show_x_guidelines => true,
			:scale_x_integers => true,
			:scale_y_integers => true,
			:show_data_points => true,
			:show_data_values => false,
			:stagger_x_labels => true,
			:style_sheet => "/plugin_assets/redmine_graphs/stylesheets/issue_age.css",
			:timescale_divisions => "1 weeks",
			:width => 800,
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
	    })
	    
		# Generate the closed_on line
		updated_count = 0
	  	updated_on_line = Hash.new
	  	issues_by_updated_on.each { |updated_on, issues| updated_on_line[(updated_on-1).to_s] = updated_count; updated_count += issues.size; updated_on_line[updated_on.to_s] = updated_count }
	  	updated_on_line[Date.today.to_s] = updated_count
	    graph.add_data({
			:data => updated_on_line.sort.flatten,
			:title => l(:field_updated_on)
	    })
	    	    
	    # Compile the graph
		headers["Content-Type"] = "image/svg+xml"
		send_data(graph.burn, :type => "image/svg+xml", :disposition => "inline")
	end
	
	# Displays open and total issue counts over time
	def target_version_graph

		# Initialize the graph
		graph = SVG::Graph::TimeSeries.new({
			:area_fill => true,
			:height => 300,
			:no_css => true,
			:show_x_guidelines => true,
			:scale_x_integers => true,
			:scale_y_integers => true,
			:show_data_points => true,
			:show_data_values => false,
			:stagger_x_labels => true,
			:style_sheet => "/plugin_assets/redmine_graphs/stylesheets/target_version.css",
			:width => 800,
			:x_label_format => "%b %d"
		})

		# Group issues
	  	issues_by_created_on = @version.fixed_issues.group_by {|issue| issue.created_on.to_date }.sort
		issues_by_updated_on = @version.fixed_issues.group_by {|issue| issue.updated_on.to_date }.sort
		issues_by_closed_on = @version.fixed_issues.collect { |issue| issue if issue.closed? }.compact.group_by {|issue| issue.updated_on.to_date }.sort
	  		  	
	  	# Set the scope of the graph
	  	scope_end_date = issues_by_updated_on.keys.last
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
	
	
	private
	
	def find_open_issues
	    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
	    deny_access unless User.current.allowed_to?(:view_issues, @project, :global => true)
		@issues = Issue.visible.find(:all, :include => [:status], :conditions => ["#{IssueStatus.table_name}.is_closed=?", false]) if @project.nil?
		@issues = @project.issues.collect { |issue| issue unless issue.closed? }.compact unless @project.nil?
	rescue ActiveRecord::RecordNotFound
		render_404
	end
		
	def find_all_issues
	    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
	    deny_access unless User.current.allowed_to?(:view_issues, @project, :global => true) if @project.nil?
		@issues = Issue.visible.find(:all, :include => [:project])
		@issues = @project.issues unless @project.nil?
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