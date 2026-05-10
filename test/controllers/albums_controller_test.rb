require "test_helper"

class AlbumsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @album = albums(:one)
    @previous_basic_auth_username = ENV["BASIC_AUTH_USERNAME"]
    @previous_basic_auth_password = ENV["BASIC_AUTH_PASSWORD"]
    ENV["BASIC_AUTH_USERNAME"] = "albums-admin"
    ENV["BASIC_AUTH_PASSWORD"] = "secret"
  end

  teardown do
    ENV["BASIC_AUTH_USERNAME"] = @previous_basic_auth_username
    ENV["BASIC_AUTH_PASSWORD"] = @previous_basic_auth_password
  end

  test "index requires basic authentication" do
    get albums_path

    assert_response :unauthorized
  end

  test "index rejects invalid basic authentication" do
    get albums_path, headers: basic_auth_headers("albums-admin", "wrong")

    assert_response :unauthorized
  end

  test "index accepts valid basic authentication" do
    get albums_path, headers: valid_basic_auth_headers

    assert_response :success
  end

  test "create requires basic authentication" do
    post albums_path, params: { album: { title: "Private", status: "draft" } }

    assert_response :unauthorized
  end

  test "update requires basic authentication" do
    patch album_path(@album), params: { album: { title: "Updated" } }

    assert_response :unauthorized
  end

  test "destroy requires basic authentication" do
    delete album_path(@album)

    assert_response :unauthorized
  end

  private
    def valid_basic_auth_headers
      basic_auth_headers("albums-admin", "secret")
    end

    def basic_auth_headers(username, password)
      {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      }
    end
end
