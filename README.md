# Organ-Organizer

### April 14, 2018
### Nathan Romike

## Description
Organ-Organizer is an CLI application written in Ruby. This application communicates to a REST API to gather and flatten organ specific data.

## Technologies Used
Ruby, rspec, pry, json, bundler

## Setup
### Start the REST API
* In terminal, clone the [Mock REST API repository](https://source.datanerd.us/mmayo/mock-api/blob/master/server.rb):
`git clone git@source.datanerd.us:mmayo/mock-api.git`
* Execute the following terminal command chain to install the API's dependencies, set an API key, and serve the API:
`bundle install && export API_KEY="<API_KEY_HERE>" && bundle exec rackup`

### Running the Organ-Organizer
* In terminal, clone [this repository](https://source.datanerd.us/nromike/organ_organizer):
`git clone git@source.datanerd.us:nromike/organ_organizer.git`
* Execute the following terminal command to run the Organ-Organizer:
`ruby organ_organizer/mock_processor.rb`
* The processed data is outputted into the `processed_output.json` file at:
`organ_organizer/processed_output.json`

## License
MIT License
Copyright (c) 2018 Nathan Romike
