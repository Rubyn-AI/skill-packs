#!/usr/bin/env ruby
# frozen_string_literal: true

# Walks all pack directories, reads manifest.json from each,
# and outputs a consolidated registry.json at the repo root.
#
# Usage:
#   ruby scripts/generate-registry.rb
#   ruby scripts/generate-registry.rb --pretty   # human-readable output

require "json"
require "time"

REPO_ROOT = File.expand_path("..", __dir__)
REGISTRY_PATH = File.join(REPO_ROOT, "registry.json")

# Directories to skip when scanning for packs
IGNORED_DIRS = %w[. .. .git .github scripts template node_modules].freeze

def pack_directories
  Dir.entries(REPO_ROOT)
    .select { |entry| File.directory?(File.join(REPO_ROOT, entry)) }
    .reject { |entry| IGNORED_DIRS.include?(entry) || entry.start_with?(".") }
    .sort
end

def read_manifest(pack_dir)
  manifest_path = File.join(REPO_ROOT, pack_dir, "manifest.json")

  unless File.exist?(manifest_path)
    warn "  SKIP #{pack_dir}/ — no manifest.json found"
    return nil
  end

  JSON.parse(File.read(manifest_path))
rescue JSON::ParserError => e
  warn "  ERROR #{pack_dir}/manifest.json — invalid JSON: #{e.message}"
  nil
end

def build_pack_entry(manifest)
  {
    "name" => manifest["name"],
    "displayName" => manifest["displayName"],
    "description" => manifest["description"],
    "category" => manifest["category"],
    "skillCount" => Array(manifest["skills"]).size,
    "author" => manifest["author"],
    "version" => manifest["version"],
    "updatedAt" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "compatibility" => manifest["compatibility"],
    "tags" => Array(manifest["tags"]),
    "gemDependencies" => Array(manifest["gemDependencies"]),
    "installCommand" => "/install-skills #{manifest['name']}",
    "url" => "https://rubyn.ai/skills/#{manifest['name']}"
  }
end

def build_categories(packs)
  packs
    .group_by { |p| p["category"] }
    .map { |id, entries| { "id" => id, "name" => category_display_name(id), "count" => entries.size } }
    .sort_by { |c| c["name"] }
end

def category_display_name(id)
  {
    "frontend" => "Frontend",
    "auth" => "Authentication",
    "payments" => "Payments & Commerce",
    "background" => "Background Jobs",
    "api" => "API & Serialization",
    "testing" => "Testing",
    "infra" => "Infrastructure",
    "data" => "Data & Search",
    "authorization" => "Authorization"
  }.fetch(id, id.capitalize)
end

# --- Main ---

puts "Scanning pack directories..."
packs = []

pack_directories.each do |dir|
  manifest = read_manifest(dir)
  next unless manifest

  packs << build_pack_entry(manifest)
  puts "  OK #{dir}/ — #{manifest['displayName']} (#{Array(manifest['skills']).size} skills)"
end

if packs.empty?
  warn "No valid packs found. registry.json not written."
  exit 1
end

total_skills = packs.sum { |p| p["skillCount"] }
categories = build_categories(packs)

registry = {
  "packs" => packs.sort_by { |p| p["name"] },
  "categories" => categories,
  "totalPacks" => packs.size,
  "totalSkills" => total_skills,
  "generatedAt" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
}

pretty = ARGV.include?("--pretty")
json_output = pretty ? JSON.pretty_generate(registry) : JSON.generate(registry)

File.write(REGISTRY_PATH, json_output + "\n")
puts "\nWrote registry.json — #{packs.size} packs, #{total_skills} skills"
