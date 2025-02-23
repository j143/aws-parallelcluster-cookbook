# frozen_string_literal: true

#
# Cookbook:: aws-parallelcluster
# Recipe:: intel_mpi
#
# Copyright:: 2013-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the
# License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions and
# limitations under the License.

return unless node['conditions']['intel_mpi_supported']

intelmpi_modulefile = "/opt/intel/impi/#{node['cluster']['intelmpi']['version']}/intel64/modulefiles/intelmpi"
intelmpi_installer_archive = "l_mpi_#{node['cluster']['intelmpi']['version']}.tgz"
intelmpi_installer_path = "#{node['cluster']['sources_dir']}/#{intelmpi_installer_archive}"
intelmpi_installer_url = "https://#{node['cluster']['region']}-aws-parallelcluster.s3.#{node['cluster']['region']}.#{aws_domain}/archives/impi/#{intelmpi_installer_archive}"

# fetch intelmpi installer script
remote_file intelmpi_installer_path do
  source intelmpi_installer_url
  mode '0744'
  retries 3
  retry_delay 5
  not_if { ::File.exist?("/opt/intel/impi/#{node['cluster']['intelmpi']['version']}") }
end

bash "install intel mpi" do
  cwd node['cluster']['sources_dir']
  code <<-INTELMPI
    set -e
    tar -xf #{intelmpi_installer_archive}
    cd l_mpi_#{node['cluster']['intelmpi']['version']}/
    ./install.sh -s silent.cfg --accept_eula
    mv rpm/EULA.txt /opt/intel/impi/#{node['cluster']['intelmpi']['version']}
    cd ..
    rm -rf l_mpi_#{node['cluster']['intelmpi']['version']}*
  INTELMPI
  creates "/opt/intel/impi/#{node['cluster']['intelmpi']['version']}"
end

append_if_no_line "append intel modules file dir to modules conf" do
  path node['cluster']['modulepath_config_file']
  line "/opt/intel/impi/#{node['cluster']['intelmpi']['version']}/intel64/modulefiles/"
end

execute "rename intel mpi modules file name" do
  command "mv #{node['cluster']['intelmpi']['modulefile']} #{intelmpi_modulefile}"
  creates intelmpi_modulefile.to_s
end
