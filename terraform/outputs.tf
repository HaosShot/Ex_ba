output "app1_ip" {
  value = yandex_compute_instance.app1.network_interface[0].nat_ip_address
}

output "app2_ip" {
  value = yandex_compute_instance.app2.network_interface[0].nat_ip_address
}

output "load_balancer_ip" {
  value = tolist([
    for l in yandex_lb_network_load_balancer.react_lb.listener :
    l.external_address_spec[*].address
  ])[0]
}
