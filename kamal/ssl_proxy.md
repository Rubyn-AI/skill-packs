---
name: kamal-ssl-proxy
triggers:
  - kamal ssl
  - kamal https
  - lets encrypt
  - traefik
  - kamal proxy
  - kamal tls
  - custom domain
gems:
  - kamal
rails: ">=7.0"
---

# Kamal SSL & Proxy (kamal-proxy)

Kamal 2 uses `kamal-proxy` (replacing Traefik) as its reverse proxy. It handles SSL termination via Let's Encrypt, request routing, and zero-downtime deploys.

## Pattern: Automatic SSL with Let's Encrypt

```yaml
# config/deploy.yml
proxy:
  ssl: true
  host: myapp.com
```

That's it. `kamal-proxy` automatically provisions and renews a Let's Encrypt certificate for `myapp.com`. DNS must point to your server before deploying.

## Pattern: Multiple domains

```yaml
proxy:
  ssl: true
  host: myapp.com
  aliases:
    - www.myapp.com
    - api.myapp.com
```

All domains share the same SSL certificate (SAN/multi-domain cert). Each domain routes to the same application.

## Pattern: Custom SSL certificate

```yaml
proxy:
  ssl: true
  host: myapp.com
  ssl_certificate_path: /etc/ssl/myapp.com.pem
  ssl_private_key_path: /etc/ssl/myapp.com.key
```

Use for wildcard certs, enterprise CAs, or when Let's Encrypt isn't an option.

## Pattern: Force HTTPS redirect

```ruby
# config/environments/production.rb
config.force_ssl = true
```

Rails handles the redirect at the application level. Alternatively, configure it at the proxy level:

```yaml
proxy:
  ssl: true
  host: myapp.com
  response_headers:
    Strict-Transport-Security: "max-age=63072000; includeSubDomains"
```

## Pattern: Health check endpoint

```yaml
proxy:
  ssl: true
  host: myapp.com
  healthcheck:
    path: /up
    interval: 1
    timeout: 5
```

`kamal-proxy` checks `/up` on the container. If the check fails, the container is not routed traffic. Rails 7.1+ generates `/up` by default.

## Pattern: Custom headers

```yaml
proxy:
  response_headers:
    X-Frame-Options: DENY
    X-Content-Type-Options: nosniff
    Referrer-Policy: strict-origin-when-cross-origin
    Permissions-Policy: "camera=(), microphone=(), geolocation=()"
```

## Anti-pattern: Exposing ports directly without the proxy

```yaml
# BAD — bypasses SSL, health checks, and zero-downtime
servers:
  web:
    hosts: [192.168.0.1]
    options:
      publish: "3000:3000"  # Direct port exposure

# GOOD — let kamal-proxy handle routing
proxy:
  ssl: true
  host: myapp.com
```

Always go through the proxy. It handles SSL termination, rolling deploys, and health-check-based routing.

## Debugging SSL issues

```bash
# Check proxy status
kamal proxy details

# View proxy logs
kamal proxy logs

# Reboot the proxy (if certificate is stuck)
kamal proxy reboot

# Test SSL
curl -vI https://myapp.com
```

Common issues: DNS not pointing to the server yet (Let's Encrypt can't verify), port 80/443 blocked by firewall, rate-limited by Let's Encrypt (too many cert requests).
