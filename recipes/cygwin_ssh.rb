# Recipe for replacing the OpenSSH server installed by Packer on Windows
# with Cygwin SSH, which is more flexible and useful

user_data            = Chef::EncryptedDataBagItem.load('users', node.build.user)
cygwin_download_path = Chef::Config['file_cache_path']
old_service          = "OpenSSHd"
new_service          = "sshd"
cygwin_mirror        = "http://mirrors.sonic.net/cygwin"
cygwin_installer_cmd = "setup.exe -q -O -R #{node.build.cygwin_home} -s #{cygwin_mirror}"

remote_file "#{cygwin_download_path}/setup.exe" do
  source "http://cygwin.com/setup-x86_64.exe"
  action :create
end

execute "setup.exe" do
  cwd cygwin_download_path
  command cygwin_installer_cmd
  not_if { File.exists?(node.build.cygwin_home) }
end

packages = %w{openssh cygrunsrv}

packages.each do |package|
  execute "install Cygwin package: #{package}" do
    cwd cygwin_download_path
    command "#{cygwin_installer_cmd} -P #{package}"
  end
end

env 'Path' do
  action :modify
  delim  ";"
  value "#{node.build.cygwin_home}\\bin"
end

template "#{node.build.cygwin_home}/etc/sshd_config"

batch "remove #{old_service}" do
  code <<-EOH
  cygrunsrv -E #{old_service}
  cygrunsrv -R #{old_service}
  EOH
  only_if "cygrunsrv -Q #{old_service}"
end

batch "install #{new_service} service" do
  code <<-EOH
  ssh-keygen -A
  cygrunsrv -I #{new_service} -d \"CYGWIN SSH\" -p /usr/sbin/sshd -a \"-D\" -y tcpip -u #{node.build.user} -w #{user_data['password']}
  EOH
  not_if("cygrunsrv -Q #{new_service}").include? 'Running'
end

# Grant build user Logon As A Service Right
remote_file "#{node.build.home}/ntrights.exe" do
  source "#{node.build.s3_isos}/ntrights.exe"
  checksum "xxxxxxx"
end

execute "grant SeServiceLogonRight to #{node.build.user}" do
  cwd node.build.home
  command "ntrights.exe -u #{node.build.user} +r SeServiceLogonRight"
end

batch "create FW rools" do
  code <<-EOH
  netsh advfirewall firewall add rule name="CygwinSSHD" dir=in action=allow service=#{new_service} enable=yes
  netsh advfirewall firewall add rule name="CygwinSSHD" dir=in action=allow program="#{node.build.cygwin_home}\\usr\\sbin\\sshd.exe" enable=yes
  netsh advfirewall firewall add rule name="cygwin_ssh" dir=in action=allow protocol=TCP localport=22
  EOH
end

directory "#{node.build.cygwin_home}/home/#{node.build.user}/.ssh" do
  recursive true
end

pem_file = "#{node.build.cygwin_home}/home/#{node.build.user}/.ssh/id_rsa"

file pem_file do
  content user_data['ssh_pem']
  mode "0600"
  owner node.build.user
end

cookbook_file "#{node.build.cygwin_home}/home/#{node.build.user}/.ssh/known_hosts"
cookbook_file "#{node.build.cygwin_home}/home/#{node.build.user}/.ssh/authorized_keys"


