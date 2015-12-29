#!/usr/bin/ruby -W0
require 'rubygems'
require 'rbvmomi'
require 'yaml'
require 'time'

# Load config
config = YAML.load_file('/docker/config.yml')

# Establish connections
vim = RbVmomi::VIM.connect host: config['host'], user: config['user'], password: config['pass'], :insecure => true
rootFolder = vim.serviceInstance.content.rootFolder

# convert bytes into gigabytes
def btog(bytes)
  return bytes / 1024 / 1024 / 1024
end

# Fetch Datastore info
def get_datastore_metadata(datastore,datacentre)
  hosts = []
  datastore.host.each do |host|
    hosts.push(host.key.name.to_s)
  end

  capacity = datastore.summary.capacity.to_i
  freespace = datastore.summary.freeSpace.to_i
  usedspace = capacity - freespace
  usedpercent = usedspace.to_f / capacity.to_f * 100

  metadata = [
    :datacentre => datacentre,
    :hosts => hosts,
    :name => datastore.info.name.to_s,
    :freeSpaceGB => btog(freespace).to_s,
    :usedSpaceGB => btog(usedspace).to_s,
    :usedPercent => usedpercent.round(2).to_s + '%',
    :freePercent => (100 - usedpercent).round(2).to_s + '%'
  ]; return metadata
end

# Fetch Host info
def get_host_metadata(dc)
  host = dc.hostFolder.children.first.host.first
  name = host.summary.config.name.to_s
  runtime = (Time.now - Time.parse(host.summary.runtime.bootTime.to_s)) / 60 / 60 / 24

  cpu_speed = host.hardware.cpuInfo.hz.to_f / 1000 / 1000
  cpu_used = host.summary.quickStats.overallCpuUsage.to_i
  cpu_cores = host.hardware.cpuInfo.numCpuCores.to_i
  cpu_percent = cpu_used / cpu_speed * cpu_cores

  memory_total = host.hardware.memorySize.to_i / 1024 / 1024
  memory_used = host.summary.quickStats.overallMemoryUsage.to_i
  memory_percent = memory_used.to_f / memory_total.to_f * 100

  metadata = {
    :name => name,
    :runtime => runtime.round,
    :cpu_speed => cpu_speed.round(3),
    :cpu_used => cpu_used,
    :cpu_cores => cpu_cores,
    :cpu_percent => cpu_percent.round(2).to_s + '%',
    :memory_total => memory_total,
    :memory_used => memory_used,
    :memory_percent => memory_percent.round(2).to_s + '%'
  }; return metadata
end

# Fetch VM Info
def get_vm_metadata(vm)

  cpu_usage = vm.summary.quickStats.overallCpuUsage.to_f
  cpu_cores = vm.summary.config.numCpu.to_i
  cpu_speed = vm.datastore.first.host.first.key.hardware.cpuInfo.hz.to_f / 1000 /1000
  cpu_percent = cpu_usage / (cpu_speed * cpu_cores) * 100
  memory = vm.summary.quickStats.hostMemoryUsage.to_i
  memory_percent = 0.to_s + '%'

  metadata = {
    :name => vm.name.to_s,
    :cpu_percent => cpu_percent.round(2),
    :memory_percent => memory_percent
  }; return metadata
end

# Loop over all of the hosts
hosts = Array.new
vms = Array.new
rootFolder.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
  hosts.push(get_host_metadata(dc))
  dc.vmFolder.childEntity.grep(RbVmomi::VIM::VirtualMachine).each do |x|
    vms.push(get_vm_metadata(x))
  end
end

# Loop over all of the datastores
data = Array.new
rootFolder.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc |
  datacentre = dc.name
  dc.datastore.each do |x|
    data.push(get_datastore_metadata(x,datacentre).first)
  end
end

# Build the response in nagios format
r = 'OK | '
hosts.each do |x|
  r = r + 'cpu=' + x[:cpu_percent].to_s + ';;;; ' + 'memory=' + x[:memory_percent].to_s + ';;;; ' + 'uptime.days=' + x[:runtime].to_s + ';;;; '
end
vms.each do |x|
  r = r + 'vm.' + x[:name].to_s + '.cpu=' + x[:cpu_percent].to_s + ';;;; ' + 'vm.' + x[:name].to_s + '.memory_percent=' + x[:memory_percent].to_s + ';;;; '
end
data.each do |x|
  name = 'disk.' + x[:name].to_s; capacity = x[:capacityGB].to_s; freespace = x[:freeSpaceGB].to_s; usedspace = x[:usedSpaceGB].to_s; usedpercent = x[:usedPercent].to_s; freepercent = x[:freePercent].to_s
  r = r + name + '.free_gb=' + freespace + ';;;; ' + name + '.used_gb=' + usedspace + ';;;; ' + name + '.percent_used=' + usedpercent + ';;;; ' + name + '.percent_free=' + freepercent + ';;;; '
end

# Echo out the response
puts r
