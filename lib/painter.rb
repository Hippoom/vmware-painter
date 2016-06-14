require 'neography'
require 'yaml'
require 'rbvmomi'
require 'optparse'
require 'logger'


options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: painter.rb [options]"

  opts.on('-c', '--config=<config file path>', 'Config file path') { |v| options[:config] = v }

end.parse!

config = YAML.load_file(options[:config])

vcenter = config["vcenter"]
neo4j = config["neo4j"]
logging = config["logging"]

log = Logger.new STDOUT
log.formatter = proc do |severity, datetime, progname, msg|
    date_format = datetime.strftime("%Y-%m-%d'T'%H:%M:%S.%L%z")
    "[#{date_format}] [#{severity}]: #{msg}\n"
end

if logging
  log.level = Logger.const_get(logging["level"]) if logging["level"]
end

Neography.configure do |config|
  config.protocol             = neo4j["protocol"] if neo4j["protocol"]
  config.server               = neo4j["host"] if neo4j["host"]
  config.port                 = neo4j["port"] if neo4j["port"]
  config.log_enabled          = neo4j["log_enabled"] if neo4j["log_enabled"]
  config.log_file          = neo4j["log_file"] if neo4j["log_file"]
  config.slow_log_threshold   = neo4j["slow_log_threshold"] if neo4j["slow_log_threshold"]
  config.max_threads          = neo4j["max_threads"] if neo4j["max_threads"]
  config.authentication       = neo4j["authentication"] if neo4j["authentication"]
  config.username             = neo4j["user"] if neo4j["user"]
  config.password             = neo4j["password"] if neo4j["password"]
  config.http_send_timeout    = neo4j["http_send_timeout"] if neo4j["http_send_timeout"]
  config.http_receive_timeout = neo4j["http_receive_timeout"] if neo4j["http_receive_timeout"]
end

neo = Neography::Rest.new

vim = RbVmomi::VIM.connect host: vcenter["host"], user: vcenter["user"], password: vcenter["password"], insecure: true
datacenter = vim.serviceInstance.find_datacenter(vcenter["datacenter"]) or fail "datacenter not found"
host_cluster_group = datacenter.hostFolder.childEntity.grep(RbVmomi::VIM::ClusterComputeResource)
host_noncluster_group = datacenter.hostFolder.childEntity.grep(RbVmomi::VIM::HostSystem)

host_group = host_noncluster_group.concat(host_cluster_group.map{|cluster| cluster.host}.flatten)

host_group.each do |host|

  log.debug "Begin to paint #{host._ref}..."
  # HostSystem
  host_node = Neography::Node.create_unique("idx_obj_id",
    "obj_id",
    host.name,
    {
      "obj_id" => host.name
    },
    neo
  )
  # all properties should be updated after the node creation
  # otherwise the properties won't get updated if the node exists
  host_node["name"] = host.name
  host_node["hostname"] = host.name
  host_node["ip_addr"] = host.name
  host_node["ref"] = host._ref
  host_node.add_labels("Host")

  # Datastore
  datastore_nodes = host.datastore.map do |ds|
    log.debug "Begin to paint #{ds._ref}."
    datastore_node = Neography::Node.create_unique("idx_obj_id",
      "obj_id",
      ds.name,
      {
        "obj_id" => ds.name
      },
      neo
    )
    datastore_node["ref"] = ds._ref
    datastore_node["name"] = ds.name
    datastore_node.add_labels("Datastore")
    mounted_at = neo.create_unique_relationship("idx_obj_relationship",
      "depends_on",
      {
        "datastore" => datastore_node.obj_id,
        "host" => host_node.obj_id
      },
      "mounted",
      datastore_node,
      host_node,
      {
        "start" => host_node.obj_id,
        "end" => datastore_node.obj_id
      })
    log.debug "Finish to paint #{ds._ref}."
    datastore_node
  end

  # VirtualMachine
  host.vm.each do |vm|
    log.debug "Begin to paint #{vm._ref}."
    if vm.guest.hostName
      vm_node = Neography::Node.create_unique("idx_obj_id",
        "obj_id",
        vm.guest.hostName,
        {
          "obj_id" => vm.guest.hostName
        },
        neo)
      vm_node["ref"] = vm._ref
      vm_node["name"] = vm.name
      vm_node["hostname"] = vm.guest.hostName if vm.guest.hostName
      vm_node["ip_addr"] = vm.guest.ipAddress if vm.guest.ipAddress
      vm_node.add_labels("VirtualMachine")
      neo.create_unique_relationship("idx_obj_relationship",
        "depends_on",
        {
          "vm" => vm_node.obj_id,
          "host" => host_node.obj_id
        },
        "hosted_at",
        vm_node,
        host_node,
        {
          "start" => vm_node.obj_id,
          "end" => host_node.obj_id
        }) # every vm is hosted at one and only one host

      vm.datastore.each do |ds|

        datastore_node = datastore_nodes.detect {|d| d["name"] == ds.name}
        neo.create_unique_relationship("idx_obj_relationship",
        "depends_on",
        {
          "vm" => vm_node.obj_id,
          "datastore" => datastore_node.obj_id
        },
        "mounted",
        datastore_node,
        vm_node,
        {
          "start" => vm_node.obj_id,
          "end" => datastore_node.obj_id
        })
      end
    end
    log.debug "Finish to paint #{vm._ref}."
  end
  log.debug "Finish to paint #{host._ref}."
end
