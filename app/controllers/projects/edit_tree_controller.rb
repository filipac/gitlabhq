# Controller for edit a repository's file
class Projects::EditTreeController < Projects::ApplicationController
  include ExtractsPath

  # Authorize
  before_filter :authorize_read_project!
  before_filter :authorize_code_access!
  before_filter :require_non_empty_project

  before_filter :edit_requirements, only: [:show, :update]

  def show
    @last_commit = Gitlab::Git::Commit.last_for_path(@repository, @ref, @path).sha
  end

  def update
    edit_file_action = Gitlab::Satellite::EditFileAction.new(current_user, @project, @ref, @path)
    updated_successfully = edit_file_action.commit!(
      params[:content],
      params[:commit_message],
      params[:last_commit]
    )

    if updated_successfully
      redirect_to project_blob_path(@project, @id), notice: "Your changes have been successfully commited"
    else
      flash[:notice] = "Your changes could not be commited, because the file has been changed"
      render :show
    end
  end

  private

  def edit_requirements
    @blob = @repository.blob_at(@commit.id, @path)

    unless @blob
      redirect_to project_blob_path(@project, @id), notice: "You can only edit text files"
    end

    allowed = if project.protected_branch? @ref
                can?(current_user, :push_code_to_protected_branches, project)
              else
                can?(current_user, :push_code, project)
              end

    return access_denied! unless allowed

    unless @repository.branch_names.include?(@ref)
      redirect_to project_blob_path(@project, @id), notice: "You can only edit this file if you are on top of a branch"
    end
  end
end
