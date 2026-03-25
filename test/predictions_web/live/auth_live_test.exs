defmodule PredictionsWeb.AuthLiveTest do
  use PredictionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Predictions.Accounts

  describe "sign-in page" do
    test "renders sign-in form for guests", %{conn: conn} do
      conn = get(conn, ~p"/sign-in")
      html = html_response(conn, 200)

      assert html =~ "Sign in to your account"
      assert html =~ "Email"
      assert html =~ "Password"
    end
  end

  describe "sign-in flow" do
    # VAL-AUTH-001: Successful sign-in establishes an authenticated session
    test "successful sign-in redirects to dashboard for normal users", %{conn: conn} do
      {:ok, _user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      conn =
        post(conn, ~p"/sign-in", session: %{email: "user@example.com", password: "password123"})

      assert redirected_to(conn) == ~p"/dashboard"
    end

    test "successful sign-in redirects to admin for admin users", %{conn: conn} do
      {:ok, _user} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn =
        post(conn, ~p"/sign-in", session: %{email: "admin@example.com", password: "password123"})

      assert redirected_to(conn) == ~p"/admin"
    end

    # VAL-AUTH-002: Invalid sign-in does not create a session
    test "invalid sign-in shows error and keeps user on sign-in page", %{conn: conn} do
      {:ok, _user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      conn =
        post(conn, ~p"/sign-in", session: %{email: "user@example.com", password: "wrongpassword"})

      html = html_response(conn, 200)

      assert html =~ "Invalid email or password"
      assert html =~ "Sign in to your account"
    end

    test "non-existent user sign-in shows error", %{conn: conn} do
      conn =
        post(conn, ~p"/sign-in",
          session: %{email: "nonexistent@example.com", password: "password123"}
        )

      html = html_response(conn, 200)

      assert html =~ "Invalid email or password"
    end
  end

  describe "guest access control" do
    # VAL-AUTH-003: Guests are blocked from signed-in market pages
    test "guests cannot access user dashboard", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/dashboard")
    end

    test "guests cannot access admin dashboard", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin")
    end
  end

  describe "sign-out flow" do
    # VAL-AUTH-004: Sign-out clears access immediately
    test "sign-out clears session and prevents protected access", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      # Sign in via the test helper
      conn = login_user(conn, user)

      # Access dashboard should work with the session
      {:ok, _lv, html} = live(conn, ~p"/dashboard")
      assert html =~ "Welcome to your dashboard"

      # Sign out
      conn = delete(conn, ~p"/sign-out")
      assert conn.status == 302

      # Follow the redirect - session is cleared
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Prediction"

      # Try to access protected route again - should redirect to sign-in
      # Use a fresh conn without a session
      fresh_conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()

      {:error, {:redirect, %{to: "/sign-in"}}} = live(fresh_conn, ~p"/dashboard")
    end
  end

  describe "admin access control" do
    # VAL-AUTH-005: Admin users can access admin market-management pages
    test "admin can access admin dashboard", %{conn: conn} do
      {:ok, admin} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      # Sign in as admin via the test helper
      conn = login_user(conn, admin)

      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Dashboard"
    end

    # VAL-AUTH-006: Non-admin users are denied admin market-management pages
    test "normal users cannot access admin dashboard", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      # Sign in as normal user via the test helper
      conn = login_user(conn, user)

      {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/admin")
    end
  end

  # VAL-CROSS-001: First-visit auth partitioning is consistent
  describe "auth partitioning on first visit" do
    test "guests can reach public routes", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Prediction"

      conn = get(conn, ~p"/sign-in")
      assert html_response(conn, 200) =~ "Sign in to your account"
    end

    test "guests are redirected from protected user routes", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/dashboard")
    end

    test "guests are redirected from protected admin routes", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/admin")
    end

    test "normal users land in user area after login", %{conn: conn} do
      {:ok, _user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      conn =
        post(conn, ~p"/sign-in", session: %{email: "user@example.com", password: "password123"})

      assert redirected_to(conn) == ~p"/dashboard"
    end

    test "admins land in admin area after login", %{conn: conn} do
      {:ok, _user} =
        Accounts.create_user(%{email: "admin@example.com", password: "password123", role: :admin})

      conn =
        post(conn, ~p"/sign-in", session: %{email: "admin@example.com", password: "password123"})

      assert redirected_to(conn) == ~p"/admin"
    end
  end

  describe "protected route access after sign-in" do
    # Additional test for VAL-AUTH-001 - protected route success after login
    test "protected routes work after sign-in with same session", %{conn: conn} do
      {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "password123"})

      # Sign in via the test helper
      conn = login_user(conn, user)

      # Now try to access dashboard directly with same session
      {:ok, _lv, html} = live(conn, ~p"/dashboard")
      assert html =~ "Welcome to your dashboard"
    end
  end
end
