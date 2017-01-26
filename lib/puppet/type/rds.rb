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

require 'puppet_x/intechwifi/logical'
require 'puppet_x/intechwifi/constants'

Puppet::Type.newtype(:rds) do
  ensurable

  newparam(:name, :namevar => true) do
    validate do |value|
      fail("RDS name `#{value}` is not allowed by AWS.") unless /^[a-z][a-z0-9\-]+$/ =~ value
    end
  end

  #  read only properties...
  newproperty(:region) do
    defaultto 'us-east-1'
    validate do |value|
      regions = PuppetX::IntechWIFI::Constants.Regions
      fail("Unsupported AWS Region #{value} we support the following regions #{regions}") unless regions.include? value
    end
  end

  newproperty(:engine) do
    validate do |value|
      engines = PuppetX::IntechWIFI::Constants.RDS_Engines
      fail("Unsupported AWS RDS Engine #{value} we support the following engines #{engines}") unless engines.include? value
    end
  end

end

