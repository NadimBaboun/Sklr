-- Create a SQL function for authenticating directly from the users table
-- Execute this in the Supabase SQL Editor

-- First, create a secure function to authenticate users
CREATE OR REPLACE FUNCTION authenticate_user(user_email TEXT, user_password TEXT)
RETURNS json AS $$
DECLARE
  user_record RECORD;
  result json;
BEGIN
  -- Check if the user exists and password matches
  SELECT * INTO user_record
  FROM users
  WHERE email = user_email AND password = user_password;
  
  -- If user found, return success with user data
  IF FOUND THEN
    SELECT json_build_object(
      'success', true,
      'user_id', user_record.id,
      'username', user_record.username,
      'email', user_record.email
    ) INTO result;
    RETURN result;
  ELSE
    -- No matching user found
    SELECT json_build_object(
      'success', false,
      'message', 'Invalid email or password'
    ) INTO result;
    RETURN result;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a REST endpoint for authentication
-- This creates a custom API endpoint at /rest/v1/rpc/authenticate_user
COMMENT ON FUNCTION authenticate_user IS 'Authenticates a user directly from the users table';

-- Grant anonymous access to this function
GRANT EXECUTE ON FUNCTION authenticate_user TO anon; 