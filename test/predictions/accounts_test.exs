defmodule Predictions.AccountsTest do
  use Predictions.DataCase, async: true

  alias Predictions.Accounts
  alias Predictions.Accounts.User

  describe "create_user/1" do
    test "creates a user with valid attributes" do
      attrs = %{
        email: "user@example.com",
        password: "password123"
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.email == "user@example.com"
      assert user.role == :user
      assert user.hashed_password != nil
      assert user.hashed_password != "password123"
    end

    test "creates an admin user with admin role" do
      attrs = %{
        email: "admin@example.com",
        password: "password123",
        role: :admin
      }

      assert {:ok, user} = Accounts.create_user(attrs)
      assert user.role == :admin
    end

    test "requires email and password" do
      assert {:error, changeset} = Accounts.create_user(%{})
      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires unique email" do
      _user = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      assert {:error, changeset} =
               Accounts.create_user(%{email: "user@example.com", password: "different123"})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "requires valid email format" do
      assert {:error, changeset} =
               Accounts.create_user(%{email: "invalid", password: "password123"})

      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "requires password of at least 8 characters" do
      assert {:error, changeset} =
               Accounts.create_user(%{email: "user@example.com", password: "short"})

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end

  describe "authenticate_user/2" do
    test "returns user for valid credentials" do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      assert {:ok, authenticated_user} =
               Accounts.authenticate_user("user@example.com", "password123")

      assert authenticated_user.id == user.id
    end

    test "returns error for invalid password" do
      {:ok, _user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      assert {:error, :unauthorized} =
               Accounts.authenticate_user("user@example.com", "wrongpassword")
    end

    test "returns error for non-existent email" do
      assert {:error, :unauthorized} =
               Accounts.authenticate_user("nonexistent@example.com", "password123")
    end
  end

  describe "session management" do
    test "create_session/1 creates a session token" do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      token = Accounts.create_session(user)
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "get_user_by_session_token/1 returns user for valid token" do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      token = Accounts.create_session(user)

      assert found_user = Accounts.get_user_by_session_token(token)
      assert found_user.id == user.id
    end

    test "get_user_by_session_token/1 returns nil for invalid token" do
      assert Accounts.get_user_by_session_token("invalid_token") == nil
    end

    test "delete_session_token/1 removes session" do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      token = Accounts.create_session(user)

      assert :ok = Accounts.delete_session_token(token)
      assert Accounts.get_user_by_session_token(token) == nil
    end
  end

  describe "User.admin?/1" do
    test "returns true for admin user" do
      {:ok, user} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      assert User.admin?(user) == true
    end

    test "returns false for normal user" do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})
      assert User.admin?(user) == false
    end
  end
end
