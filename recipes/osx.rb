# Install and configure XCode

hg_version       = "3.7.2"
hg_url           = "#{node.build.s3_isos}/TortoiseHg-#{hg_version}-mac-x64.dmg"
hg_checksum      = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

case node["platform_version"]
when /^10\.11/
  xcode_cli_url      = "#{node.build.s3_isos}/Command_Line_Tools_OS_X_10.11_for_Xcode_7.3.dmg"
  xcode_url          = "#{node.build.s3_isos}/Xcode_7.3.dmg"
  xcode_checksum     = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  xcode_cli_checksum = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  xcode_cli_pkg_name = "Command Line Tools (OS X 10.11)"
  xcode_version      = "7.3"
  xcode_last_gm_lic  = "EA1187"
when /^10\.10/
  xcode_cli_url      = "#{node.build.s3_isos}/Command_Line_Tools_OS_X_10.10_for_Xcode_6.4.dmg"
  xcode_url          = "#{node.build.s3_isos}/Xcode_6.4.dmg"
  xcode_checksum     = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  xcode_cli_checksum = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  xcode_cli_pkg_name = "Command Line Tools (OS X 10.10)"
  xcode_version      = "6.4"
  xcode_last_gm_lic  = "EA1187"
end

bash "Install VMWare tools" do
  code <<-EOH
  TOOLS_PATH="#{node.build.home}/darwin.iso"
  TMPMOUNT=`/usr/bin/mktemp -d /tmp/vmware-tools.XXXX`
  hdiutil attach "$TOOLS_PATH" -mountpoint "$TMPMOUNT"
  INSTALLER_PKG="$TMPMOUNT/Install VMware Tools.app/Contents/Resources/VMware Tools.pkg"
  installer -verbose -pkg "$TMPMOUNT/Install VMware Tools.app/Contents/Resources/VMware Tools.pkg" -target /
  EOH
end

dmg_package "Xcode" do
  source xcode_url
  checksum xcode_checksum
  action :install
end

dmg_package xcode_cli_pkg_name do
  source xcode_cli_url
  checksum xcode_cli_checksum
  volumes_dir "Command Line Developer Tools"
  type "pkg"
  package_id "com.apple.pkg.CLTools_Executables"
  action :install
end

template "/Library/Preferences/com.apple.dt.Xcode.plist" do
  source "com.apple.dt.Xcode.plist.erb"
  owner "root"
  group "wheel"
  mode 00644
  variables({
    :last_gm_license => xcode_last_gm_lic,
    :version => xcode_version
  })
  action :create
end

dmg_package "TortoiseHg" do
  volumes_dir "TortoiseHg-#{hg_version}"
  source hg_url
  checksum hg_checksum
  action :install
end

link "/usr/local/bin/hg" do
  to "/Applications/TortoiseHg.app/Contents/Resources/lib/python2.7/hg"
end

script_dir = node.build.home
%w{osx_set_autologin.py osx_set_random_hostname.py}.each do |file|
  cookbook_file "#{script_dir}/#{file}" do
    mode 0755
  end
end

execute "Set Autologin" do
  command "python #{script_dir}/osx_set_autologin.py"
end

cron "Set random hostname" do
  command "#{script_dir}/osx_set_random_hostname.py"
  time :reboot
end
