# consul-backup
Create a backup of a consul database and uploads it to S3, using vault to lease
S3 credentials.

## Install
Intended to be run through nomad, or some other container scheduler:
```
job "consul-backup" {
  type = "batch"
  datacenters = ["dc1"]

  task "backup" {
    driver = "docker"

    config {
      image = "beamnetwork/consul-backup:latest"
      force_pull = true
    }

    env {
      VAULT_ADDR = "https://127.0.0.1:8200"
      BUCKET = "my-backups-bucket"
      PREFIX = "consul-backups-prefix"
      VAULT_STS_ROLE = "consul-backups-role"
    }

    resources {
      cpu = 500
      memory = 512
    }

    vault {
      policies = ["consul-backups"]
    }
  }
}
```

The corresponding permissions must exist in the consul-backups vault policy:
```
path "aws/sts/consul-backups" {
  capabilities = ["read"]
}
```

## Usage
First, set the required environment variables:
 - VAULT_ADDR
 - VAULT_TOKEN
 - VAULT_STS_ROLE
 - BUCKET
 - PREFIX

Then you should be able to run the container:
```
docker run -e "VAULT_ADDR=$VAULT_ADDR" -e "VAULT_TOKEN=$VAULT_TOKEN" -e "VAULT_STS_ROLE=$VAULT_STS_ROLE" -e "BUCKET=$BUCKET" -e "PREFIX=$PREFIX" beamnetwork/consul-backup
```

## Contributing

PRs accepted.

## License
MIT © Eco Inc. 2020
