#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates a skill pack directory:
#   - manifest.json exists and has valid schema
#   - All files listed in manifest.skills exist on disk
#   - All .md files in the directory are listed in manifest.skills
#   - Each skill file has valid YAML frontmatter
#   - Version format is semver
#
# Usage:
#   ruby scripts/validate-pack.rb hotwire
#   ruby scripts/validate-pack.rb hotwire stripe   # validate multiple
#   ruby scripts/validate-pack.rb --all             # validate every pack

require "json"
require "yaml"

REPO_ROOT = File.expand_path("..", __dir__)
IGNORED_DIRS = %w[. .. .git .github scripts template node_modules].freeze

REQUIRED_MANIFEST_FIELDS = %w[name displayName description version author category skills].freeze
OPTIONAL_MANIFEST_FIELDS = %w[tags compatibility gemDependencies].freeze
SEMVER_REGEX = /\A\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?\z/

REQUIRED_FRONTMATTER_FIELDS = %w[name triggers].freeze
OPTIONAL_FRONTMATTER_FIELDS = %w[gems rails].freeze

class PackValidator
  attr_reader :pack_name, :errors, :warnings

  def initialize(pack_name)
    @pack_name = pack_name
    @pack_dir = File.join(REPO_ROOT, pack_name)
    @errors = []
    @warnings = []
  end

  def validate
    validate_directory_exists
    return self unless errors.empty?

    validate_manifest
    # Only bail if manifest couldn't be parsed at all.
    # Schema-level errors (bad version, missing fields) shouldn't
    # prevent checking skill files — we want all errors in one pass.
    return self unless @manifest

    validate_skill_files
    validate_unlisted_files
    self
  end

  def valid?
    errors.empty?
  end

  private

  def validate_directory_exists
    return if File.directory?(@pack_dir)

    @errors << "Directory '#{@pack_name}/' does not exist"
  end

  def validate_manifest
    manifest_path = File.join(@pack_dir, "manifest.json")

    unless File.exist?(manifest_path)
      @errors << "manifest.json not found in #{@pack_name}/"
      return
    end

    begin
      @manifest = JSON.parse(File.read(manifest_path))
    rescue JSON::ParserError => e
      @errors << "manifest.json is not valid JSON: #{e.message}"
      return
    end

    validate_manifest_schema
    validate_version_format
    validate_skills_array
  end

  def validate_manifest_schema
    REQUIRED_MANIFEST_FIELDS.each do |field|
      if @manifest[field].nil? || (@manifest[field].respond_to?(:empty?) && @manifest[field].empty?)
        @errors << "manifest.json missing required field: '#{field}'"
      end
    end

    # Validate field types
    validate_field_type("name", String)
    validate_field_type("displayName", String)
    validate_field_type("description", String)
    validate_field_type("version", String)
    validate_field_type("author", String)
    validate_field_type("category", String)
    validate_field_type("skills", Array)
    validate_field_type("tags", Array) if @manifest.key?("tags")
    validate_field_type("gemDependencies", Array) if @manifest.key?("gemDependencies")
    validate_field_type("compatibility", Hash) if @manifest.key?("compatibility")
  end

  def validate_field_type(field, expected_type)
    return unless @manifest.key?(field)
    return if @manifest[field].is_a?(expected_type)

    @errors << "manifest.json field '#{field}' should be #{expected_type}, got #{@manifest[field].class}"
  end

  def validate_version_format
    return unless @manifest["version"].is_a?(String)

    unless @manifest["version"].match?(SEMVER_REGEX)
      @errors << "Version '#{@manifest['version']}' is not valid semver (expected: MAJOR.MINOR.PATCH)"
    end
  end

  def validate_skills_array
    return unless @manifest["skills"].is_a?(Array)

    if @manifest["skills"].empty?
      @errors << "manifest.json 'skills' array is empty — pack must contain at least one skill"
    end

    @manifest["skills"].each do |skill|
      unless skill.is_a?(String) && skill.end_with?(".md")
        @errors << "Skill entry '#{skill}' must be a string ending in .md"
      end
    end
  end

  def validate_skill_files
    return unless @manifest && @manifest["skills"].is_a?(Array)

    @manifest["skills"].each do |skill_file|
      skill_path = File.join(@pack_dir, skill_file)

      unless File.exist?(skill_path)
        @errors << "Listed skill file '#{skill_file}' does not exist in #{@pack_name}/"
        next
      end

      validate_frontmatter(skill_file, skill_path)
    end
  end

  def validate_unlisted_files
    return unless @manifest && @manifest["skills"].is_a?(Array)

    md_files = Dir.glob(File.join(@pack_dir, "*.md")).map { |f| File.basename(f) }
    listed = @manifest["skills"]

    unlisted = md_files - listed - ["README.md"]
    unlisted.each do |file|
      @warnings << "Markdown file '#{file}' exists but is not listed in manifest.json skills array"
    end
  end

  def validate_frontmatter(skill_file, skill_path)
    content = File.read(skill_path)

    unless content.start_with?("---\n")
      @errors << "#{skill_file} — missing YAML frontmatter (must start with ---)"
      return
    end

    end_index = content.index("\n---\n", 4) || content.index("\n---\r\n", 4)
    unless end_index
      @errors << "#{skill_file} — YAML frontmatter not closed (missing ending ---)"
      return
    end

    yaml_str = content[4..end_index]

    begin
      frontmatter = YAML.safe_load(yaml_str)
    rescue Psych::SyntaxError => e
      @errors << "#{skill_file} — invalid YAML frontmatter: #{e.message}"
      return
    end

    unless frontmatter.is_a?(Hash)
      @errors << "#{skill_file} — frontmatter must be a YAML mapping, got #{frontmatter.class}"
      return
    end

    REQUIRED_FRONTMATTER_FIELDS.each do |field|
      if frontmatter[field].nil? || (frontmatter[field].respond_to?(:empty?) && frontmatter[field].empty?)
        @errors << "#{skill_file} — frontmatter missing required field: '#{field}'"
      end
    end

    if frontmatter["triggers"].is_a?(Array) && frontmatter["triggers"].empty?
      @errors << "#{skill_file} — 'triggers' array is empty (must have at least one trigger)"
    end
  end
end

# --- Main ---

def resolve_pack_names(args)
  if args.include?("--all")
    Dir.entries(REPO_ROOT)
      .select { |entry| File.directory?(File.join(REPO_ROOT, entry)) }
      .reject { |entry| IGNORED_DIRS.include?(entry) || entry.start_with?(".") }
      .sort
  else
    args.reject { |a| a.start_with?("-") }
  end
end

if ARGV.empty?
  warn "Usage: ruby scripts/validate-pack.rb <pack-name> [pack-name2 ...]"
  warn "       ruby scripts/validate-pack.rb --all"
  exit 1
end

pack_names = resolve_pack_names(ARGV)

if pack_names.empty?
  warn "No pack names provided."
  exit 1
end

all_valid = true

pack_names.each do |pack_name|
  validator = PackValidator.new(pack_name).validate

  if validator.valid? && validator.warnings.empty?
    puts "PASS #{pack_name}"
  elsif validator.valid?
    puts "PASS #{pack_name} (with warnings)"
    validator.warnings.each { |w| puts "  WARN: #{w}" }
  else
    puts "FAIL #{pack_name}"
    validator.errors.each { |e| puts "  ERROR: #{e}" }
    validator.warnings.each { |w| puts "  WARN: #{w}" }
    all_valid = false
  end
end

puts
if all_valid
  puts "All packs valid."
  exit 0
else
  puts "Validation failed."
  exit 1
end
