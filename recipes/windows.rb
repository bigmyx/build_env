include_recipe "build::cygwin_ssh"

putty_home = "C:\\putty"
mercurial_pkg = "#{node.build.s3_isos}/mercurial-3.7.1-x64.msi"
git_pkg       = "#{node.build.s3_isos}/Git-2.5.1-32-bit.exe"
7zip_pkg      = "#{node.build.s3_isos}/7z1514-x64.msi"

pkgs = [
  ["git",       :inno, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"],
  ["mercurial", :msi,  "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"],
  ["7zip",      :msi,  "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"],
  ### more packages here ###
]

paths = [
  "C:\\Python27",
  "C:\\Program Files (x86)\\Git\\bin",
  putty_home
]

pkgs.each do |name, type, sum|
  package name do
    source "#{name}_pkg"
    installer_type type
    checksum sum
    action :install
  end
end

# Install Visual Studio
include_recipe "build::visualstudio"

build_ppk = Chef::EncryptedDataBagItem.load('users', 'ppk')
template "#{node.build.home}/build.ppk" do
  variables(
    key_content: build_ppk['key_content'],
    key_mac: build_ppk['key_mac']
  )
end

execute "Store repo host key in cache" do
  command "echo y | #{putty_home}\\plink -i #{node.build.home}\\build.ppk -ssh build@example.com exit"
end

paths.each do |path|
  env 'Path' do
    action :modify
    delim  ";"
    value path
  end
end

env 'HOME' do
  value node.build.home
end

env 'GIT_SSH' do
  value node.build.ssh_cmd
end


easy_install = 'C:\\Python27\\Scripts\\easy_install.exe'
batch "pywin32" do
  code <<-EOH
  #{easy_install} #{node.build.s3_isos}/pywin32-219.win32-py2.7.exe
  EOH
  not_if { ::File.directory?("C:\\Python27\\Lib\\site-packages\\pywin32-219-py2.7-win32.egg") }
end

directory "#{node.build.cygwin_home}/home/build/.ssh" do
  recursive true
end

cookbook_file "/Windows/System32/drivers/etc/hosts"

template "#{node.build.home}/Mercurial.ini"

# Enable auto-login and set password
winlogon_key = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
uname = Chef::EncryptedDataBagItem.load('users', node.build.user)
registry_key "set autologon for #{node.build.user}" do
  key winlogon_key
  values [
    { name: 'AutoAdminLogon', type: :string, data: '1' },
    { name: 'DefaultUsername', type: :string, data: node.build.user },
    { name: 'DefaultPassword', type: :string, data: uname['password'] },
  ]
  action :create
end

user node.build.user do
  action :modify
  password uname['password']
end


# Enable RDP
execute "Open RDP on FW" do
  command "netsh advfirewall firewall add rule name=Enable_RDP dir=in action=allow protocol=TCP localport=3389"
end
rdp_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server'
registry_key "Enable RDP" do
  key rdp_key
  values [
    {name: 'fDenyTSConnections', type: :dword, data: '0'}
  ]
end
