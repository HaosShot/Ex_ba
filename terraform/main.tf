data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.84"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}


resource "yandex_vpc_network" "net" {
  name = "net-min"
}

resource "yandex_vpc_subnet" "subnet_public" {
  name           = "subnet-public"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.cidr_block]
}

resource "yandex_vpc_security_group" "sg" {
  name       = "sg-web"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "app1" {
  name        = "app1"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }
}

resource "yandex_compute_instance" "app2" {
  name        = "app2"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }
}

resource "yandex_lb_target_group" "react_tg" {
  name      = "react-target-group"
  region_id = "ru-central1"

  depends_on = [
    yandex_compute_instance.app1,
    yandex_compute_instance.app2
  ]
  
  target {
    subnet_id = yandex_vpc_subnet.subnet_public.id
    address   = yandex_compute_instance.app1.network_interface[0].ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet_public.id
    address   = yandex_compute_instance.app2.network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "react_lb" {
  name      = "react-load-balancer"
  region_id = "ru-central1"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
   target_group_id = yandex_lb_target_group.react_tg.id

   healthcheck {
     name                = "tcp-health"
     interval            = 5
     timeout             = 2
     unhealthy_threshold = 2
     healthy_threshold   = 2

     tcp_options {
      port = 3000
     }
  }
}

}

