# WHAT?

Quick deployment of force.com classes, triggers, and pages edited locally. I created it so that I could dev in VIM and use the cli to quick save my changes to my dev org as I work.

# USAGE (unlike Bikeage)

Make sure to create the build.properties file and adjust the Deploy class instance variable, @xml_ant_build, to point to it.

Make sure you have the salesforce ant migration tool in your ant lib dir.

sudo deploy.rb ~/src/file_one.cls ~/src/file_two.trigger ~/src/file_three.page