# Common build Attributes
default['build']['user']           = "build"
# Some content was delete from here on purpose
default['build']['ssh_cmd']        = platform?('windows') ? "#{node.build.cygwin_home}\\bin\\ssh.exe" : "/usr/bin/ssh"
