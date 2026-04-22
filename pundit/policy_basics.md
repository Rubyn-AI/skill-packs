---
name: pundit-policy-basics
triggers:
  - pundit policy
  - authorize
  - policy class
  - pundit setup
  - authorization
gems:
  - pundit
rails: ">=7.0"
---

# Pundit Policy Basics

## Setup

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
```

`verify_authorized` ensures every action calls `authorize`. Forgetting an `authorize` call raises an error instead of silently allowing access.

## Pattern: Basic policy

```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def show?
    true  # Anyone can view
  end

  def create?
    user.present?  # Must be logged in
  end

  def update?
    user == record.author || user.admin?
  end

  def destroy?
    user == record.author || user.admin?
  end
end
```

## Pattern: Using authorize in controllers

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])
    authorize @post
  end

  def create
    @post = Post.new(post_params)
    authorize @post

    if @post.save
      redirect_to @post
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @post = Post.find(params[:id])
    authorize @post

    if @post.update(post_params)
      redirect_to @post
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

`authorize @post` checks `PostPolicy#update?` (inferred from the action name). The first argument is the record, the policy is resolved by class name convention.

## Pattern: ApplicationPolicy base class

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
```

Default-deny: every action is `false` unless explicitly overridden. This is the safe default.

## Anti-pattern: Authorizing with conditionals instead of policies

```ruby
# BAD — authorization logic scattered across controllers
def update
  @post = Post.find(params[:id])
  if current_user == @post.author || current_user.admin?
    @post.update(post_params)
  else
    redirect_to root_path, alert: "Not authorized"
  end
end

# GOOD — centralized in a policy
def update
  @post = Post.find(params[:id])
  authorize @post
  @post.update!(post_params)
end
```
