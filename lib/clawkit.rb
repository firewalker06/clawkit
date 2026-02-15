# frozen_string_literal: true

require "yaml"

module Clawkit
  PROJECT_DIR = File.expand_path("..", __dir__)

  # Load .env file if it exists, setting variables that aren't already set.
  def self.load_env
    env_file = File.join(PROJECT_DIR, ".env")
    return unless File.file?(env_file)

    File.readlines(env_file).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      if line =~ /\A([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\z/
        ENV[$1] ||= $2.gsub(/\A['"]|['"]\z/, "")
      end
    end
  end

  # Load config.yml, aborting with a friendly message if missing.
  def self.load_config
    path = File.join(PROJECT_DIR, "config.yml")
    unless File.exist?(path)
      abort "Error: config.yml not found. Copy config.yml.sample to config.yml and edit it."
    end
    YAML.safe_load_file(path)
  end

  # Resolve hosts from ENV override or config fallback.
  def self.resolve_hosts(config)
    hosts = if ENV["HOSTS"]
      ENV["HOSTS"].split(",").map(&:strip)
    else
      config.fetch("hosts")
    end
    abort "Error: No hosts configured." if hosts.empty?
    hosts
  end

  # Validate that a path contains only safe characters.
  def self.safe_path?(path)
    path.match?(/\A[\w.\/-]+\z/)
  end
end
