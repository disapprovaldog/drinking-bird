require "buildkite"

eval(File.read(".env"))
Buildkite.configure do |config|
  config.token = BUILDKITE_AGENT_TOKEN
  config.org = BUILDKITE_ORG
end

Buildkite::Pipeline.list.data.each do |pipeline|
  puts "Pipeline: #{pipeline.name}"
end
