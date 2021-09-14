locals {
  # Converts list of domains and subdomains like:
  #    [api.example.com, static.example.com, www.example.com]
  #  To a Set of unique top level domains:
  #    [example.com]
  domains = toset(
    [for s in var.static_sites : regex("[^.]+.[^.]+$", s.hostname)]
  )

  # Maps all full domain sites like: 
  #    [api.example.com, static.example.com, www.example.com]
  #  To their top level domain:
  #    {
  #      api.example.com: example.com
  #      static.example.com: example.com
  #      www.example.com: example.com
  #    }
  static_site_domains_to_root_domain = {
    for site in var.static_sites : site.hostname => regex("[^.]+.[^.]+$", site.hostname)
  }

  # Converts the static_sites array like
  #    [
  #       { hostname: api.example.com, project: projectA },
  #       { hostname: static.example.com, project: projectB },
  #       { hostname: my.www.example.com, project: projectC },
  #    ]
  #  To their top level domain:
  #    {
  #      api.example.com: { hostname: api.example.com, project: projectA },
  #      static.example.com: { hostname: static.example.com, project: projectB },
  #      www.example.com: { hostname: my.www.example.com, project: projectC },
  #    }
  static_sites = {
    for site in var.static_sites : site.hostname => site
  }
}
