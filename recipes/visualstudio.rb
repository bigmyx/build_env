# Install Visual Studio
vs_iso_file    = "#{node.build.home}/vs.iso"
vs_extract_dir = "#{node.build.home}\\vs_iso"
unzip          = '"C:\\Program Files\\7-Zip\\7z.exe"'
# Download ISO
remote_file vs_iso_file do
  source "#{node.build.s3_isos}/vs.iso"
  checksum "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  not_if { ::File.exists?(vs_extract_dir) }
end

execute "Extract VS" do
  command  "#{unzip} e #{vs_iso_file} -o#{vs_extract_dir} -r -y -aoa"
  not_if { ::File.exists?(vs_extract_dir) }
end

cookbook_file "#{node.build.home}/AdminDeployment.xml"

windows_package "Install VS" do
  source "#{vs_extract_dir}\\vs_professional.exe"
  installer_type :custom
  options "/adminfile #{node.build.home}\\AdminDeployment.xml /quiet /norestart"
  returns [0, 127, 3010]
  timeout 7200
end

# Clean up

directory vs_extract_dir do
  action :delete
  recursive true
end

file vs_iso_file do
  action :delete
end
