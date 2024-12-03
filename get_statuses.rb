require "buildkite"
require "yaml"
require "date"
require "time"
require "fileutils"

eval(File.read(".env"))

Buildkite.configure do |config|
  config.token = BUILDKITE_AGENT_TOKEN
  config.org = BUILDKITE_ORG
end

def get_cache(type)
  pipeline_cache_files=Dir["#{type}*.yml"]

  pipeline_cache_files.grep_v("#{type}-#{Date.today.to_s}.yml").each do |filename|
    FileUtils.rm_rf filename
  end

  pipeline_cache_files.grep("#{type}-#{Date.today.to_s}.yml")[0]
end

def write_cache(type, data)
  File.open("#{type}-#{Date.today.to_s}.yml", "wt") do |f|
    f.write(data.to_yaml)
  end
end

pipeline_cache = get_cache("pipelines")

pipelines=[]
if pipeline_cache
  pipelines = YAML.parse(File.read(pipeline_cache)).to_ruby
else
  page=1
  loop do
    list=Buildkite::Pipeline.list(page: page)

    break unless list.total > 0

    puts "<<< #{page} >>>"
    list.data.each do |pipeline|
      pipelines << pipeline
    end
    page += 1
  end

  write_cache("pipelines", pipelines)
end

filtered_pipelines = pipelines.select { |pipeline| SLUG_MATCH.any? { |match| pipeline.slug.match?(match) } }

filtered_pipelines.each do |pipeline|
  puts pipeline.name
end

from_time = (Time.now - 90 * 86400).iso8601

builds_cache = get_cache("builds")

builds=[]
if builds_cache
  builds = YAML.parse(File.read(builds_cache)).to_ruby
else
  filtered_pipelines.map(&:slug).each do |pipeline_slug|
    page=1
    loop do
      list=Buildkite::Build.list(org: BUILDKITE_ORG, pipeline: pipeline_slug, page: page, created_from: from_time)

      break unless list.total > 0
      puts "<<< #{pipeline_slug} #{page} >>>"

      list.data.each do |build|
        builds << build
      end
      page += 1
    end
  end
  write_cache("builds", builds)
end

build_tally = builds.inject({}) do |hash, build|
  build.jobs.each do |job|
    next unless job.finished_at && job.started_at
    hash[job.exit_status] ||= {}
    hash[job.exit_status][:count] ||= 0
    hash[job.exit_status][:total_time] ||= 0
    hash[job.exit_status][:count] += 0
    hash[job.exit_status][:total_time] += Time.parse(job.finished_at) - Time.parse(job.started_at)
  end
  hash
end

puts build_tally.to_yaml


