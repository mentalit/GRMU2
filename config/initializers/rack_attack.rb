Rack::Attack.throttle("logins/ip", limit: 10, period: 60) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end