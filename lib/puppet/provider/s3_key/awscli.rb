#  Copyright (C) 2017 IntechnologyWIFI / Michael Shaw
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.


require 'json'
require 'tempfile'
require 'puppet_x/intechwifi/s3'

Puppet::Type.type(:s3_key).provide(:awscli) do
  desc "Using the aws command line python application to implement changes"
  commands :awscli => "aws"

  def create
    pair = PuppetX::IntechWIFI::S3.name_to_bucket_key_pair(@resource[:name])

    set_s3_content(pair[:bucket], pair[:key], @resource[:content], @resource[:metadata])

    @property_hash[:name] = resource[:name]
    @property_hash[:content] = resource[:content]
    @property_hash[:owner] = !resource[:owner].nil? ? resource[:owner] : PuppetX::IntechWIFI::S3.get_owner_for_bucket(pair[:bucket]) {| *arg | awscli(*arg)}
    @property_hash[:grants] = resource[:grants] if !resource[:grants].nil?


    if !@property_hash[:grants].nil?
      set_policy_args = [
        's3api',
        'put-object-acl',
        '--bucket', pair[:bucket],
        '--key', pair[:key],
        '--access-control-policy', PuppetX::IntechWIFI::S3.set_s3_grants_policy(@property_hash[:owner], @property_hash[:grants])
      ]
      awscli(set_policy_args)
    end

    debug("created object for AWS owner=#{@property_hash[:owner]}")
  end

  def destroy
    pair = PuppetX::IntechWIFI::S3.name_to_bucket_key_pair(@resource[:name])
    awscli('s3api', 'delete-object', '--bucket', pair[:bucket], '--key', pair[:key])
  end

  def exists?
    pair = PuppetX::IntechWIFI::S3.name_to_bucket_key_pair(@resource[:name])

    data = JSON.parse(awscli('s3api', 'head-object', '--bucket', pair[:bucket], '--key', pair[:key]))
    @property_hash[:name] = @resource[:name]
    @property_hash[:content] = get_s3_content(pair[:bucket], pair[:key]) if !@resource[:content].nil? and @resource[:content].length == Integer(data["ContentLength"])
    @property_hash[:metadata] = data["Metadata"]

    acl = JSON.parse(awscli('s3api', 'get-object-acl', '--bucket', pair[:bucket], '--key', pair[:key]))

    @property_hash[:grants] = acl["Grants"].map{|g| PuppetX::IntechWIFI::S3.grant_json_to_property(g)}
    @property_hash[:owner] = PuppetX::IntechWIFI::S3.owner_to_property(acl["Owner"])

    true
  rescue Exception => e
    debug("EXCEPTION => #{e}")
    false
  end

  def flush
    if @property_flush and @property_flush.length > 0
      pair = PuppetX::IntechWIFI::S3.name_to_bucket_key_pair(@property_hash[:name])

      metadata = @property_flush[:metadata].nil? ? @property_hash[:metadata] : @property_flush[:metadata]
      content = @property_flush[:content].nil? ? @property_hash[:content] : @property_flush[:content]

      set_s3_content(pair[:bucket], pair[:key], content, metadata) if !@property_flush[:content].nil? or !@property_flush[:metadata].nil?
      if !@property_flush[:grants].nil? or !@property_flush[:owner].nil?
        #  We need to set the new owner / grants...
        owner = @property_flush[:owner].nil? ? @property_hash[:owner] : @property_flush[:owner]
        grants = @property_flush[:grants].nil? ? @property_hash[:grants] : @property_flush[:grants]

        set_policy_args = [
            's3api',
            'put-object-acl',
            '--bucket', pair[:bucket],
            '--key', pair[:key],
            '--access-control-policy', PuppetX::IntechWIFI::S3.set_s3_grants_policy(owner, grants)
        ]
        awscli(set_policy_args)
      end
    end
  end

  def get_s3_content(bucket, key)
    file = Tempfile.open(['s3api', '.s3api'])
    awscli('s3api', 'get-object', '--bucket', bucket, '--key', key, file.path )
    file.read()
  rescue Exception => e
    ""
  end

  def set_s3_content(bucket, key, content, metadata)
    file = Tempfile.open(['s3api', '.s3api'])
    file << content
    file.close
    args = ['s3api', 'put-object', '--bucket', bucket, '--key',  key, '--body', file.path]
    args << ['--metadata', metadata.to_json] if !metadata.nil?
    awscli(args.flatten)
  end

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  mk_resource_methods

  def content=(value)
    @property_flush[:content] = value
  end

  def grants=(value)
    @property_flush[:grants] = value
  end

  def owner=(value)
    @property_flush[:owner] = value
  end

  def metadata=(value)
    @property_flush[:metadata] = value
  end

end
