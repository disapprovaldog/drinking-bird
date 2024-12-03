require "buildkite"
require "yaml"
require "date"
require "fileutils"

eval(File.read(".env"))

Buildkite.configure do |config|
  config.token = BUILDKITE_AGENT_TOKEN
  config.org = BUILDKITE_ORG
end

pipeline_cache_files=Dir["pipelines*.yml"]

pipelines_cache_files.grep_v("pipelines-#{Date.today.to_s}.yml").each do |filename|
  FileUtils.rm_rf filename
end

pipeline_cache=pipeline_cache_files.grep("pipelines-#{Date.today.to_s}.yml")[0]

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

  File.open("pipelines.yml", "wt") do |f|
    f.write(pipelines.to_yaml)
  end
end

