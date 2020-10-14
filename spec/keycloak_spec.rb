require "spec_helper"

RSpec.describe Keycloak do

  Keycloak.realm = 'realm_test'
  Keycloak.auth_server_url = "https://test.org/auth"
  Keycloak.validate_token_when_call_has_role = false

  let(:token_endpoint) { "https://test.org/auth/token_endpoint" }
  let(:authorization_endpoint) { "https://test.org/auth/authorization_endpoint" }

  before do
    Keycloak.class_variable_set :@@installation_file, nil
    openid_configuration = JSON.generate({ "token_endpoint" => token_endpoint, "authorization_endpoint" => authorization_endpoint })
    openid_configuration_response = instance_double("response", :code => 200, :body => openid_configuration )
    allow(RestClient).to receive(:get).with("#{Keycloak.auth_server_url}/realms/#{Keycloak.realm}/.well-known/openid-configuration").and_return(openid_configuration_response)
  end

  it "has a version number" do
    expect(Keycloak::VERSION).not_to be nil
  end

  describe 'Configuration module' do
    describe '.installation_file=' do
      it 'should raise an error if given file does not exist' do
        expect{ Keycloak.installation_file = 'random/file.json' }.to raise_error(Keycloak::InstallationFileNotFound)
      end
    end

    describe '.installation_file' do

      it 'should return the old default installation file' do
        expect(Keycloak.installation_file).to eq(Keycloak::OLD_KEYCLOAK_JSON_FILE)
      end

      it 'should return the new default installation file' do
        allow(File).to receive(:exist?).with(Keycloak::KEYCLOAK_JSON_FILE).and_return(Keycloak::KEYCLOAK_JSON_FILE)
        expect(Keycloak.installation_file).to eq(Keycloak::KEYCLOAK_JSON_FILE)
      end

      it 'should return custom installation file location if previously set' do
        Keycloak.installation_file = 'spec/fixtures/test_installation.json'
        expect(Keycloak.installation_file).to eq('spec/fixtures/test_installation.json')
      end
    end
  end

  describe 'Client module' do

    let(:client_id) { "djhpyigvsbefpuydgcosjdhvv" }
    let(:client_secret) { "wxcqsdgqrgbhzrgdfsghgf" }
    let(:header) { {'Content-Type' => 'application/x-www-form-urlencoded'} }

    describe '#get_token' do
      let(:user) { "tester" }
      let(:password) { "some_password" }

      it 'should call token endpoint without scope' do
        payload =  {
          "client_id" => client_id,
          "client_secret" => client_secret,
          "username" => user,
          "password" => password,
          "grant_type" => "password",
        }
        body = JSON.generate({ "access_token" => "zerzer", "refresh_token" => "qsfsdhtfwxc" })
        allow(RestClient).to receive(:post).with(token_endpoint, payload, header).and_return(body)

        expect(Keycloak::Client.get_token(user, password, client_id, client_secret)).to eq body
      end

      it 'should call token endpoint with scope' do
        payload =  {
          "client_id" => client_id,
          "client_secret" => client_secret,
          "username" => user,
          "password" => password,
          "grant_type" => "password",
          "scope" => "openid offline_access"
        }
        body = JSON.generate({ "access_token" => "zerzer", "refresh_token" => "qsfsdhtfwxc" })
        allow(RestClient).to receive(:post).with(token_endpoint, payload, header).and_return(body)

        expect(Keycloak::Client.get_token(user, password, client_id, client_secret, ["openid", "offline_access"])).to eq body
      end

    end


    describe '#get_token_by_code' do
      let(:code) { "piuhvygpbvpdfqvpyqfv" }
      let(:redirect_uri) { "https://test.com/callback" }

      it 'should call token endpoint without scope' do
        payload =  {
          "client_id" => client_id,
          "client_secret" => client_secret,
          "code" => code,
          "redirect_uri" => redirect_uri,
          "grant_type" => "authorization_code",
        }
        body = JSON.generate({ "access_token" => "zerzer", "refresh_token" => "qsfsdhtfwxc" })
        allow(RestClient).to receive(:post).with(token_endpoint, payload, header).and_return(body)

        expect(Keycloak::Client.get_token_by_code(code, redirect_uri, client_id, client_secret)).to eq body
      end

      it 'should call token endpoint with scope' do
        payload =  {
          "client_id" => client_id,
          "client_secret" => client_secret,
          "code" => code,
          "redirect_uri" => redirect_uri,
          "grant_type" => "authorization_code",
          "scope" => "openid offline_access"
        }
        body = JSON.generate({ "access_token" => "zerzer", "refresh_token" => "qsfsdhtfwxc" })
        allow(RestClient).to receive(:post).with(token_endpoint, payload, header).and_return(body)

        expect(Keycloak::Client.get_token_by_code(code, redirect_uri, client_id, client_secret, ["openid", "offline_access"])).to eq body
      end

    end

    describe 'url_login_redirect' do
      let(:redirect_uri) { "https://test.com/callback" }
      let(:response_type) { "code" }

      it 'should return the login redirect without scope' do
        expected_url = "#{authorization_endpoint}?#{URI.encode_www_form(response_type: response_type, client_id: client_id, redirect_uri: redirect_uri)}"

        expect(Keycloak::Client.url_login_redirect(redirect_uri, response_type, client_id)).to eq expected_url
      end

      it 'should return the login redirect with scope' do
        expected_url = "#{authorization_endpoint}?#{URI.encode_www_form(response_type: response_type, client_id: client_id, redirect_uri: redirect_uri, scope: "openid")}"

        expect(Keycloak::Client.url_login_redirect(redirect_uri, response_type, client_id, '', ["openid"])).to eq expected_url
      end

    end
  end

  describe 'Admin module' do

    describe 'list_offline_session' do
      let(:response) { "some_response" }
      let(:client_id) { "web" }
      let(:access_token) { "some_access_token" }

      it 'should perform the correct request' do
        allow(Keycloak::Admin).to receive(:generic_get).with("clients/#{client_id}/offline-sessions", nil, access_token).and_return(response)

        Keycloak::Admin.list_offline_session(client_id, access_token)
      end

    end

    describe 'delete_user' do

      let(:response) { "some_response" }
      let(:user_id) { "0a8ddaaf-21c0-471d-b568-4f1bd9dda558" }
      let(:access_token) { "some_access_token" }

      it 'should perform the correct request' do
        allow(Keycloak::Admin).to receive(:generic_delete).with("users/#{user_id}", nil, nil, access_token).and_return(response)

        Keycloak::Admin.delete_user(user_id, access_token)
      end

    end

  end
end
