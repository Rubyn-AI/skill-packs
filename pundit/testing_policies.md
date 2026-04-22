---
name: pundit-testing-policies
triggers:
  - test policy
  - policy spec
  - pundit test
  - pundit rspec
gems:
  - pundit
rails: ">=7.0"
---

# Testing Pundit Policies

## Pattern: Policy specs

```ruby
# spec/policies/post_policy_spec.rb
RSpec.describe PostPolicy, type: :policy do
  subject { described_class.new(user, post) }

  let(:post) { create(:post, author: author) }
  let(:author) { create(:user) }

  context "as a visitor (not logged in)" do
    let(:user) { nil }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:create) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "as the post author" do
    let(:user) { author }

    it { is_expected.to permit_actions([:show, :create, :update, :destroy]) }
  end

  context "as another user" do
    let(:user) { create(:user) }

    it { is_expected.to permit_actions([:show, :create]) }
    it { is_expected.to forbid_actions([:update, :destroy]) }
  end

  context "as an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_actions([:show, :create, :update, :destroy]) }
  end
end
```

Requires the `pundit-matchers` gem for `permit_action`/`forbid_action` matchers:

```ruby
# Gemfile
group :test do
  gem "pundit-matchers"
end
```

## Pattern: Scope specs

```ruby
RSpec.describe PostPolicy::Scope do
  subject { described_class.new(user, Post.all).resolve }

  let!(:published_post) { create(:post, published: true) }
  let!(:draft_post) { create(:post, published: false, author: author) }
  let!(:other_draft) { create(:post, published: false) }
  let(:author) { create(:user) }

  context "as the author" do
    let(:user) { author }

    it "includes published posts and own drafts" do
      expect(subject).to include(published_post, draft_post)
      expect(subject).not_to include(other_draft)
    end
  end

  context "as admin" do
    let(:user) { create(:user, :admin) }

    it "includes all posts" do
      expect(subject).to include(published_post, draft_post, other_draft)
    end
  end
end
```

## Anti-pattern: Only testing the happy path

```ruby
# BAD — only tests that admins can do things
it "allows admin to update" do
  expect(PostPolicy.new(admin, post).update?).to be true
end

# GOOD — test both permission and denial
it "allows the author to update" do
  expect(PostPolicy.new(author, post).update?).to be true
end

it "forbids other users from updating" do
  expect(PostPolicy.new(other_user, post).update?).to be false
end

it "forbids visitors from updating" do
  expect(PostPolicy.new(nil, post).update?).to be false
end
```

Test every role × every action combination. Authorization bugs are security bugs.
