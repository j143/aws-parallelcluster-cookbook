# frozen_string_literal: true

#
# Cookbook:: aws-parallelcluster
# Recipe:: imds
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

# slurm and custom schedulers will have imds access on the head node
if node['cluster']['node_type'] == 'HeadNode' && node['cluster']['scheduler'] != 'awsbatch'

  directory "#{node['cluster']['scripts_dir']}/imds" do
    owner 'root'
    group 'root'
    mode '0744'
    recursive true
  end

  imds_access_script = "#{node['cluster']['scripts_dir']}/imds/imds-access.sh"

  cookbook_file imds_access_script do
    source 'imds/imds-access.sh'
    owner 'root'
    group 'root'
    mode '0744'
  end

  case node['cluster']['head_node_imds_secured']
  when 'true'
    execute 'IMDS lockdown enable' do
      command(lazy { "bash #{imds_access_script} --flush && bash #{imds_access_script} --allow #{node['cluster']['head_node_imds_allowed_users'].join(',')}" })
      user 'root'
    end
  when 'false'
    execute 'IMDS lockdown disable' do
      command "bash #{imds_access_script} --flush"
      user 'root'
    end
  else
    raise "head_node_imds_secured must be 'true' or 'false', but got #{node['cluster']['head_node_imds_secured']}"
  end
end

iptables_rules_file = '/etc/parallelcluster/sysconfig/iptables.rules'

execute "Save iptables rules" do
  command "mkdir -p $(dirname #{iptables_rules_file}) && iptables-save > #{iptables_rules_file}"
end

template '/etc/init.d/parallelcluster-iptables' do
  source 'imds/parallelcluster-iptables.erb'
  user 'root'
  group 'root'
  mode '0744'
  variables(iptables_rules_file: iptables_rules_file)
end

service "parallelcluster-iptables" do
  action %i(enable start)
end

include_recipe 'aws-parallelcluster-test::test_imds'
