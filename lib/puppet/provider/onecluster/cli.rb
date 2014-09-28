# OpenNebula Puppet provider for onecluster
#
# License: APLv2
#
# Authors:
# Based upon initial work from Ken Barber
# Modified by Martin Alfke
#
# Copyright
# initial provider had no copyright
# Deutsche Post E-POST Development GmbH - 2014
#

require 'puppet/provider/one'
require 'rexml/document'

Puppet::Type.type(:onecluster).provide(:cli, :parent => Puppet::Provider::One) do

  desc "onecluster provider"

  has_command(:onecluster, "onecluster") do
    environment :HOME => '/root', :ONE_AUTH => '/var/lib/one/.one/one_auth'
  end

  has_command(:onedatastore, "onedatastore") do
    environment :HOME => '/root', :ONE_AUTH => '/var/lib/one/.one/one_auth'
  end

  has_command(:onehost, "onehost") do
    environment :HOME => '/root', :ONE_AUTH => '/var/lib/one/.one/one_auth'
  end

  has_command(:onevnet, "onevnet") do
    environment :HOME => '/root', :ONE_AUTH => '/var/lib/one/.one/one_auth'
  end

  mk_resource_methods

  def create
    onecluster('create', resource[:name])
    self.debug "We have hosts: #{resource[:hosts]}"
    self.debug "We have vnets: #{resource[:vnets]}"
    resource[:hosts].each { |host|
      self.debug "Adding host #{host} to cluster #{resource[:name]}"
      onecluster('addhost', resource[:name], host)
    }
    resource[:vnets].each { |vnet|
      self.debug "Adding vnet #{vnet} to cluster #{resource[:name]}"
      onecluster('addvnet', resource[:name], vnet)
    }
    resource[:datastores].each { |datastore|
      self.debug "Adding datastore #{datastore} to cluster #{resource[:name]}"
      onecluster('adddatastore', resource[:name], datastore)
    }
    @property_hash[:ensure] = :present
  end

  def destroy
    resource[:hosts].each do |host|
      onecluster('delhost', resource[:name], host)
    end
    resource[:vnets].each do |vnet|
      onecluster('delvnet', resource[:name], vnet)
    end
    resource[:datastores].each do |datastore|
      onecluster('deldatastore', resource[:name], datastore)
    end
    onecluster('delete', resource[:name])
    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present
  end


  def self.instances
    resource = OpenNebula::ClusterPool.new(self.client)
    rc = resource.info
    throw Puppet::Error rc.message if OpenNebula.is_error?(rc)
    resource.get_hash['CLUSTER_POOL'].collect do |k, v|
      datastores = v['DATASTORES']['ID'].map do |id|
        resource = OpenNebula::Datastore.new_with_id(id, self.client)
        rc = resource.info
        throw Puppet::Error rc.message if OpenNebula.is_error?(rc)
        resource.to_hash['DATASTORE']['NAME']
      end if v['DATASTORES'] and v['DATASTORES']['ID']
      hosts = v['HOSTS']['ID'].map do |id|
        resource = OpenNebula::Host.new_with_id(id, self.client)
        rc = resource.info
        throw Puppet::Error rc.message if OpenNebula.is_error?(rc)
        resource.to_hash['HOST']['NAME']
      end if v['HOSTS'] and v['HOSTS']['ID']
      vnets = v['VNETS']['ID'].map do |id|
        resource = OpenNebula::VirtualNetwork.new_with_id(id, self.client)
        rc = resource.info
        throw Puppet::Error rc.message if OpenNebula.is_error?(rc)
        resource.to_hash['VNET']['NAME']
      end if v['VNETS'] and v['VNETS']['ID']
      new(
        :name       => v['NAME'],
        :ensure     => :present,
        :datastores => datastores,
        :hosts      => hosts,
        :vnets      => vnets
      )
    end
  end

  def self.prefetch(resources)
    clusters = instances
    resources.keys.each do |name|
      if provider = clusters.find{ |cluster| cluster.name == name }
        resources[name].provider = provider
      end
    end
  end

  #setters
  def hosts=(value)
    hosts = @property_hash[:hosts] || []
    (hosts - value).each do |host|
      onecluster('delhost', resource[:name], host)
    end
    (value - hosts).each do |host|
      onecluster('addhost', resource[:name], host)
    end
  end
  def vnets=(value)
    vnets = @property_hash[:vnets] || []
    (vnets - value).each do |vnet|
      onecluster('delvnet', resource[:name], vnet)
    end
    (value - vnets).each do |vnet|
      onecluster('addvnet', resource[:name], vnet)
    end
  end
  def datastores=(value)
    datastores = @property_hash[:datastores] || []
    (datastores - value).each do |datastore|
      onecluster('deldatastore', resource[:name], datastore)
    end
    (value - datastores).each do |datastore|
      onecluster('adddatastore', resource[:name], datastore)
    end
  end
end
