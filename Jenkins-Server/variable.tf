variable "Name" {
  default = "Dev"
  description = "the tag name of the vpc"
}

variable "name" {
  default = "app-loadbalancer"
  description = "this is the load balancer for our application"
}

variable "load_balancer_type" {
  default = "application"
  description = "this is the type of load balancer we want to create"
  
}

variable "lb_target_name" {
  default = "app-target-group"
  description = "this is the target group for our load balancer"
}

variable "name_template" {
  default = "ubuntu-template"
  description = "this is the launch configuration for our auto scaling group"
}


