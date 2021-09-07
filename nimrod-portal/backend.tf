module "backend" {
  source = "../nimrod-portal-backend"

  namespace = "nimrod-portal"

  app                   = "nimrod-portal-backend"
  context_path          = "/nimrod"

  allowed_cors_patterns = local.frontend_cors

  db_username = "nimrod_portal"
  db_password = random_password.backend-password.result
  db_url      = "jdbc:postgresql://${module.portal-db.service_name}/nimrod_portal"

  jwt_config = var.rs_jwt_config

  rabbitmq_secret_name = "rabbitmq-default-user"

  replicas = var.replicas_backend

  nimrod_config = {
    home          = "/sw7/RCC/NimrodG/nimrod-portal"
    max_job_count = 10000000

    rabbitmq = {
      # Have to use the external endpoint because TLS only
      api      = "https://${var.amqp_domain.domain}:15671"
      user     = "nimrod_portal"
      password = "meatloaf"
    }

    remote = {
      ##
      # NB: These are from the POV of the master, which currently runs external to the cluster.
      # When that's changed, change these to use internal addresses.
      ##
      postgres_uritemplate = "postgresql://${var.db_domain.domain}/nimrod_portal?currentSchema={username}&ssl=true"
      rabbit_uritemplate   = "amqps://{username}:{amqp_password}@${var.amqp_domain.domain}/username"
      vars = {}
    }

    resource = {
      api = "http://${module.resource-server.service_name}.${var.namespace}.svc/resource"
    }

    setup = {
      workdir  = "/home/{username}/.config/nimrod-portal"
      storedir = "$${nimrod.setup.workdir}/experiments"

      agentmap = {
        Linux = {
          x86_64 = "x86_64-pc-linux-musl"
        }
      }
      agents = {
        x86_64-pc-linux-musl = "$${nimrod.home}/agents/agent-x86_64-pc-linux-musl"
      }

      amqp = {
        cert = ""
        no_verify_host = false
        no_verify_peer = false
        routing_key    = "nimrod_portal"
        # Used by both master (internal/external) and agents (external), we need to use the TLS endpoint
        uri            = "amqps://{amqp_username}:{amqp_password}@${var.amqp_domain.domain}/{amqp_username}"
      }

      transfer = {
        cert           = ""
        no_verify_host = false
        no_verify_peer = false
        uri            = "file:///QRISdata/"
      }

      resource_types = {
        hpc = "au.edu.uq.rcc.nimrodg.resource.HPCResourceType"
      }

      properties = {
        "nimrod.master.amqp.tls_protocol"               = "TLSv1.2"
        "nimrod.master.heart.expiry_retry_count"        = 5
        "nimrod.master.heart.expiry_retry_interval"     = 5
        "nimrod.master.heart.interval"                  = 0
        "nimrod.master.heart.missed_threshold"          = 3
        "nimrod.sched.default.job_buf_refill_threshold" = 100
        "nimrod.sched.default.job_buf_size"             = 1000
        "nimrod.sched.default.launch_penalty"           = -10
        "nimrod.sched.default.spawn_cap"                = 2147483647
      }
    }
  }
}