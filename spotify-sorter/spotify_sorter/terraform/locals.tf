locals {
  tagging_defaults = {
    client-prefix                 = "foo",
    supplier-prefix               = "ch",
    client-name-location          = "01",
    client-name-role              = "NET",
    environment-region            = var.region,
    environment-type              = "development",
    environment-availability-zone = null,
    cost-center                   = "development",
    risk-gdpr                     = "false",
    risk-operational              = "medium",
    risk-security                 = "medium",
    backups                       = [],
    supplier-owner = {
      name  = "Foo Baz"
      email = "foo@connectholland.nl"
    },
    client-owner = {
      name  = "Foo Bar"
      email = "example@example.org"
    }
  }
}