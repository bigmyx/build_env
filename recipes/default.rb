client_repo = "ssh://repo@example.com/client.git"
build_repo = "ssh://repo@example.com/build-tools.git"

# Platform specific dependencies
#
case node.platform
when "windows"
  include_recipe "build::windows"
when "mac_os_x"
  include_recipe "build::osx"
end

# Create SSH keys
userdata = Chef::EncryptedDataBagItem.load('users', node.build.user) # load encrypted data bag
ssh_pem = userdata['ssh_pem']
directory "#{node.build.home}/.ssh/" do
  owner node.build.user
end

file "#{node.build.home}/.ssh/id_rsa" do
  content ssh_pem
  mode 0600
  owner node.build.user
end

# Copy auth keys files
%w{authorized_keys known_hosts}.each do |file|
  cookbook_file "#{node.build.home}/.ssh/#{file}" do
    owner node.build.user
    mode 0644
  end
end

# Clone repos
directory "#{node.build.home}/src/" do
  owner node.build.user
end

repos = {
  "client" => client_repo,
  "build-tools" => build_repo
}

repos.each do |app, repo|
  git "#{node.build.home}/src/#{app}" do
    repository repo
    user node.build.user
    revision 'master'
    action :sync
    ssh_wrapper "#{node.build.ssh_cmd}"
  end
end

# Create token for retrieving more secrets over the secure connection to Vault server
token = Chef::EncryptedDataBagItem.load('vault', node.build.user)
file "#{node.build.home}/.vault_key_build" do
  content token['token']
  owner node.build.user
end


