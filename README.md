# contextifyer
A ruby script for turning a series of files into AI context

# project config
for each project, create a .rb file, of the following form:  

```rb
# Configuration for project

# Project path (absolute or relative to the script location)
@project_path = '../../../kaicycle/living-compost-hubs/compost-app'

# Exclusions (similar to .gitignore)
@exclusions = [
  '.*',
  '*.lock',
  '*-lock.json',
  'tmp',
  "fixtures",
  "go.sum",
  "node_modules",
  "bower_components",
  # "client",
  "build*",
  "build",
  "dist",
  "dummy",
  "sample",
  "vendor",
  "pubic",
  "assets",
  "images",
  "aibundler",
  "lib",
  "*.log",
  "user testing",
  "*.mov",
  "*.mp4",
  "*.pdf",
]

# Make these variables available to the main script
{
  project_path: @project_path,
  exclusions: @exclusions
}
```

# run the contextifyer
`contextify.rb <project_config_file_name>`
e.g. for `complicated_app.rb` config file, run `contextify.rb complicated_app`
