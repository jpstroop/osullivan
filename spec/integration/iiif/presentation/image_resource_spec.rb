describe IIIF::Presentation::ImageResource do
  vcr_options = {
    cassette_name: 'pul_loris_cassette',
    record: :new_episodes,
    serialize_with: :json
  }

  describe 'self#create_image_api_image_resource', vcr: vcr_options do

    let(:image_server) { 'https://libimages.princeton.edu/loris' }
    let(:valid_service_id) {
      id = 'pudl0001/4612422/00000001.jp2'
      "#{image_server}/#{id}"
    }

    let(:invalid_service_id) {
      id = 'xxxx/4612422/00000001.jp2'
      "#{image_server}/#{id}"
    }

    it 'returns an ImageResource' do
      instance = described_class.create_image_api_image_resource(service_id: valid_service_id)
      expect(instance.class).to be described_class
    end


    describe 'has expected values from our fixture' do
      it 'when copy_info is false' do
        opts = { service_id: valid_service_id }
        resource = described_class.create_image_api_image_resource(opts)
        # expect(resource['@context']).to eq 'http://iiif.io/api/presentation/2/context.json'
        # @context is only added when we call to_json...
        expect(resource['@id']).to eq 'https://libimages.princeton.edu/loris/pudl0001/4612422/00000001.jp2/full/!200,200/0/default.jpg'
        expect(resource['@type']).to eq 'dctypes:Image'
        expect(resource.format).to eq "image/jpeg"
        expect(resource.width).to eq 3047
        expect(resource.height).to eq 7200
        expect(resource.service['@context']).to eq 'http://iiif.io/api/image/2/context.json'
        expect(resource.service['@id']).to eq 'https://libimages.princeton.edu/loris/pudl0001/4612422/00000001.jp2'
        expect(resource.service['profile']).to eq 'http://iiif.io/api/image/2/level2.json'
      end
      it 'copies over all teh infos (when copy_info is true)' do
        opts = { service_id: valid_service_id, copy_info: true }
        resource = described_class.create_image_api_image_resource(opts)
        expect(resource['@id']).to eq 'https://libimages.princeton.edu/loris/pudl0001/4612422/00000001.jp2/full/!200,200/0/default.jpg'
        expect(resource['@type']).to eq 'dctypes:Image'
        expect(resource.format).to eq "image/jpeg"
        expect(resource.width).to eq 3047
        expect(resource.height).to eq 7200
        expect(resource.service['@context']).to eq 'http://iiif.io/api/image/2/context.json'
        expect(resource.service['@id']).to eq 'https://libimages.princeton.edu/loris/pudl0001%2F4612422%2F00000001.jp2'  # I do not know why this would be partially escaped, but I am not Princeton
        expect(resource.service['profile']).to eq [
          'http://iiif.io/api/image/2/level2.json',
          {
            'supports' => [
              'canonicalLinkHeader', 'profileLinkHeader', 'mirroring',
              'rotationArbitrary', 'regionSquare', 'sizeAboveFull'
            ],
            'qualities' => ['default', 'bitonal', 'gray', 'color'],
            'formats'=>['jpg', 'png', 'gif', 'webp']
          }
        ]
        expect(resource.service['tiles']).to eq [ {
          'width' =>  1024,
          'scaleFactors' =>  [ 1, 2, 4, 8, 16, 32 ] 
        } ]
        expect(resource.service['sizes']).to eq [
          {'width' => 96, 'height' =>  225 },
          {'width' => 191, 'height' =>  450 },
          {'width' => 381, 'height' =>  900 },
          {'width' => 762, 'height' => 1800 },
          {'width' => 1524, 'height' => 3600 },
          {'width' => 3047, 'height' =>  7200 }
        ]
      end
    end

    describe 'respects the params we supply' do
      it ':resource_id' do
        r_id = 'http://example.edu/images/some.jpg'
        opts = { service_id: valid_service_id, resource_id: r_id}
        resource = described_class.create_image_api_image_resource(opts)
        expect(resource['@id']).to eq r_id
      end
      it ':width' do
        width = 42
        opts = { service_id: valid_service_id, width: width}
        resource = described_class.create_image_api_image_resource(opts)
        expect(resource.width).to eq width
      end
      it ':height' do
        height = 42
        opts = { service_id: valid_service_id, height: height}
        resource = described_class.create_image_api_image_resource(opts)
        expect(resource.height).to eq height
      end
      it ':profile (service[\'profile\'])' do
        profile = 'http://iiif.io/api/image/2/level1.json'
        opts = { service_id: valid_service_id, profile: profile}
        resource = described_class.create_image_api_image_resource(opts)
        expect(resource.service['profile']).to eq profile
      end
    end

    describe 'errors' do
      it 'raises if :service_id is not included' do
        expect {
          described_class.create_image_api_image_resource
        }.to raise_error
      end
      it 'raises if the info can\'t be pulled in' do
        expect {
          described_class.create_image_api_image_resource(service_id: invalid_service_id)
        }.to raise_error
      end
    end


  end
end
