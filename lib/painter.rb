require 'neography'
require 'yaml'
require 'rbvmomi'

config = YAML.load_file("vmware.dev.yml")
vcenter = config["vcenter"]
neo4j = config["neo4j"]


Neography.configure do |config|
  config.server               = neo4j["host"]
  config.port                 = neo4j["port"]
end

neo = Neography::Rest.new

vim = RbVmomi::VIM.connect host: vcenter["host"], user: vcenter["user"], password: vcenter["password"], insecure: true
datacenter = vim.serviceInstance.find_datacenter(vcenter["datacenter"]) or fail "datacenter not found"
host_cluster_group = datacenter.hostFolder.childEntity.grep(RbVmomi::VIM::ClusterComputeResource)
host_noncluster_group = datacenter.hostFolder.childEntity.grep(RbVmomi::VIM::HostSystem)

host_group = host_noncluster_group.concat(host_cluster_group.map{|cluster| cluster.host}.flatten)

host_group.each do |host|

  # HostSystem
  host_node = Neography::Node.create_unique("idx_host",
    "id",
    host._ref,
    {
      "id" => host._ref
    },
    neo
  )
  # all properties should be updated after the node creation
  # otherwise the properties won't get updated if the node exists
  host_node["name"] = host.name,
  host_node["host"] = host.name,
  host_node["ipAddress"] = host.name
  host_node.add_labels("Host")

  # Datastore
  datastore_nodes = host.datastore.map do |ds|
    datastore_node = Neography::Node.create_unique("idx_datastore",
      "id",
      ds._ref,
      {
        "id" => ds._ref
      },
      neo
    )
    datastore_node["name"] = ds.name
    datastore_node.add_labels("Datastore")
    neo.create_unique_relationship("idx_ds_host",
      "ds_host",
      "#{datastore_node.id}-#{host_node.id}",
      "mountedAt",
      datastore_node,
      host_node)
    datastore_node
  end

  # VirtualMachine
  host.vm.each do |vm|
    vm_node = Neography::Node.create_unique("idx_vm",
      "id",
      vm._ref,
      {
        "id" => vm._ref
      },
      neo)
    vm_node["name"] = vm.name
    vm_node["host"] = vm.guest.hostName if vm.guest.hostName
    vm_node["ipAddress"] = vm.guest.ipAddress if vm.guest.ipAddress
    vm_node.add_labels("VirtualMachine")
    neo.create_unique_relationship("idx_vm_host",
      "vm_id",
      vm.name,
      "hostedAt",
      vm_node,
      host_node) # every vm is hosted at one and only one host

    vm.datastore.each do |ds|

      datastore_node = datastore_nodes.detect {|d| d["name"] == ds.name}
      neo.create_unique_relationship("idx_ds_vm",
        "ds_vm",
        "#{datastore_node.id}-#{vm_node.id}",
        "mountedAt",
        datastore_node,
        vm_node)
    end
  end
end
