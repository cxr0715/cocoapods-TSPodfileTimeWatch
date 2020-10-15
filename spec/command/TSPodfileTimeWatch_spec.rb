require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Tspodfiletimewatch do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ TSPodfileTimeWatch }).should.be.instance_of Command::Tspodfiletimewatch
      end
    end
  end
end

